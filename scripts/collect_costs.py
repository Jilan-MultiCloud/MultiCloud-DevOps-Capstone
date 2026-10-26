"""Read month-to-date costs from existing billing services; never provisions exports.

Requires Cost Explorer access, Azure Cost Management access and an existing GCP
BigQuery billing export. Billing APIs/querying may incur usage charges. Missing
sources fail the update; old data then becomes visibly stale in monitoring.
"""
import argparse
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import json
from pathlib import Path
import re
import time


def aws_cost(config):
    import boto3
    today = datetime.now(timezone.utc).date()
    result = boto3.client("ce", region_name="us-east-1").get_cost_and_usage(
        TimePeriod={"Start": str(today.replace(day=1)), "End": str(today + timedelta(days=1))},
        Granularity="MONTHLY", Metrics=["UnblendedCost"],
        **({"Filter": config["filter"]} if config.get("filter") else {}))
    rows = [row["Total"]["UnblendedCost"] for row in result["ResultsByTime"]]
    return float(sum(Decimal(row["Amount"]) for row in rows)), rows[0]["Unit"]


def azure_cost(config):
    from azure.identity import DefaultAzureCredential
    import requests
    scope = config["scope"]
    if not re.fullmatch(r"/subscriptions/[A-Za-z0-9-]+/resourceGroups/[A-Za-z0-9_.()-]+", scope):
        raise ValueError("Azure cost scope must be the capstone resource group")
    credential = DefaultAzureCredential()
    token = credential.get_token("https://management.azure.com/.default").token
    response = requests.post(
        f"https://management.azure.com{scope}/providers/Microsoft.CostManagement/query?api-version=2025-03-01",
        headers={"Authorization": f"Bearer {token}"},
        json={"type": "ActualCost", "timeframe": "MonthToDate",
              "dataset": {"granularity": "None", "aggregation": {"totalCost": {"name": "Cost", "function": "Sum"}}}},
        timeout=30)
    response.raise_for_status()
    result = response.json()["properties"]
    if result.get("nextLink"):
        raise ValueError("Unexpected paginated aggregate; no partial costs will be published")
    columns = [column["name"] for column in result["columns"]]
    rows = [dict(zip(columns, row)) for row in result["rows"]]
    if not rows:
        raise ValueError("Azure returned no billing data")
    currencies = {row["Currency"] for row in rows}
    if len(currencies) != 1:
        raise ValueError("Mixed Azure currencies")
    return float(sum(Decimal(str(row["Cost"])) for row in rows)), currencies.pop()


def gcp_cost(config):
    from google.cloud import bigquery
    table = config["table"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+", table):
        raise ValueError("Invalid BigQuery table")
    client = bigquery.Client(project=config["query_project"])
    query = f"""SELECT currency,
        SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS total
        FROM `{table}`
        WHERE project.id = @project
          AND usage_start_time >= TIMESTAMP(DATE_TRUNC(CURRENT_DATE(), MONTH))
          AND usage_start_time < CURRENT_TIMESTAMP()
        GROUP BY currency"""
    job = bigquery.QueryJobConfig(
        maximum_bytes_billed=100_000_000,
        query_parameters=[bigquery.ScalarQueryParameter("project", "STRING", config["project"])])
    rows = list(client.query(query, job_config=job).result(timeout=60))
    if len(rows) != 1:
        raise ValueError("Expected one GCP billing currency with actual data")
    return float(rows[0].total), rows[0].currency


def collect(config):
    clouds = {}
    for cloud, collector in (("aws", aws_cost), ("azure", azure_cost), ("gcp", gcp_cost)):
        actual, currency = collector(config[cloud])
        if currency != config[cloud]["currency"]:
            raise ValueError(f"{cloud} budget currency does not match billing")
        clouds[cloud] = {"actual": actual, "budget": config[cloud]["budget"],
                         "currency": currency, "source": "billing_api"}
    return {"timestamp": time.time(), "clouds": clouds}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--output", type=Path, default=Path("monitoring/data/billing.json"))
    args = parser.parse_args()
    snapshot = collect(json.loads(args.config.read_text(encoding="utf-8")))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(".tmp")
    temporary.write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
    temporary.replace(args.output)
