# Disaster Recovery Runbook

## Scope and targets

| Item | Value |
|---|---|
| Protected data | Backup files replicated by `scripts/dr_backup_sync.py` |
| Replica locations | AWS S3 (DR bucket), GCP Cloud Storage (`dr-replicas/`), Azure Blob (`dr-backups`) |
| Primary / secondary compute | GCP Cloud Run / Azure Container Apps (Route 53 failover); AWS Lambda reachable via `app/router.py` |
| Target RPO | Time since last `backup` run (run it on a schedule, e.g. daily) |
| Target RTO | Minutes: DNS TTL is 60 s, plus health-check detection (3 failures x 30 s) |

## Infrastructure

Created by Terraform (`terraform/environments/dev`):

- AWS: versioned, encrypted, private S3 bucket (`terraform output aws_dr_bucket_name`), 30-day expiry of old versions.
- Azure: storage account + private `dr-backups` container.
- GCP: Cloud Storage bucket (`terraform output gcp_bucket_name`).
- Route 53 health checks and failover records (only when `route53_zone_id` and `app_domain` are set).

## Taking a backup

```bash
export AWS_DR_BUCKET=$(terraform -chdir=terraform/environments/dev output -raw aws_dr_bucket_name)
export GCP_DR_BUCKET=$(terraform -chdir=terraform/environments/dev output -raw gcp_bucket_name)
export AZURE_STORAGE_CONNECTION_STRING="<from Azure portal or Vault>"
pip install boto3 google-cloud-storage azure-storage-blob
python scripts/dr_backup_sync.py backup ./path/to/backup.tar.gz
```

The script stores the SHA-256 on every replica and requires at least two clouds to succeed.

## Failover drill (test restore)

1. Simulate the primary outage: `curl http://127.0.0.1:8090/simulate/aws/down` (router) or stop the primary service.
2. Confirm traffic moved: `curl http://127.0.0.1:8090/status` and, with DNS enabled, `dig +short <app_domain>` returns the Azure host after about 2 minutes.
3. Restore from the secondary cloud and verify integrity:
   ```bash
   python scripts/dr_backup_sync.py restore
   ```
   The drill passes only if the downloaded file's SHA-256 matches the checksum recorded at backup time.
4. Record the result (timestamps, screenshot) in `docs/screenshots/`.
5. Bring services back: `curl http://127.0.0.1:8090/simulate/aws/up`.

## Real disaster procedure

1. Confirm the outage with the provider status page and `monitoring` alerts (Prometheus / Slack / PagerDuty).
2. Let Route 53 fail over automatically; if DNS is not enabled, point clients at the Azure URL (`terraform output azure_container_app_url`).
3. Run `restore` and load the verified file into the recovery environment.
4. After the primary recovers, verify `/health`, then let the PRIMARY record take traffic back (automatic when its health check passes).
5. Write a short post-incident note: cause, detection time, recovery time, data loss.

## Known limits

- The replicated "database" is a file backup; managed database replication (RDS / Azure SQL / Cloud SQL) is out of scope for the free-tier budget.
- Cloud Run and Azure Container Apps only serve a custom domain after the domain is mapped to each service; until then, DNS failover is demonstrated by the health-check state rather than live HTTP responses on the custom name.
