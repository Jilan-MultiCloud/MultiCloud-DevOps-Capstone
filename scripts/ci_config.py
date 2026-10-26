"""Write non-secret Terraform configuration from GitHub environment variables."""
import json
import os
from pathlib import Path


def configuration(environ):
    values = json.loads(environ.get("TF_CONFIG_JSON", "{}"))
    if not isinstance(values, dict):
        raise ValueError("TF_CONFIG_JSON must be a JSON object")
    for required in ("gcp_project_id", "gcp_bucket_name", "bucket_name", "azure_acr_name"):
        if not values.get(required):
            raise ValueError(f"TF_CONFIG_JSON is missing {required}")
    for key, variable in (("azure_image", "AZURE_IMAGE"), ("gcp_image", "GCP_IMAGE")):
        if environ.get(variable):
            values[key] = environ[variable]
    if any(word in key.lower() for key in values for word in ("password", "secret", "token", "credential")):
        raise ValueError("Do not put secrets in TF_CONFIG_JSON")
    return values


if __name__ == "__main__":
    Path("terraform/environments/dev/ci.auto.tfvars.json").write_text(
        json.dumps(configuration(os.environ)), encoding="utf-8")
