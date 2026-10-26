# Setup and operations

## Existing-resources submission path

Use main or the reviewed feature branch. Install Python 3.12+, Terraform 1.10+,
Docker Desktop, AWS CLI, Azure CLI and Google Cloud CLI. From the repository root:

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python -m unittest discover -s tests -v
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/dev init -backend=false
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev test
```

These checks do not provision cloud resources. Terraform tests use mock providers.
The database drill uses local Docker containers:

```powershell
.venv\Scripts\python -m scripts.dr_drill --output recovery/local-drill.json
```

## Authentication

Use short-lived CLI credentials locally and OIDC in CI. This implements the brief's
"Vault or a similar tool" goal without keeping static access keys in HCL or state.
Do not use Terraform Vault data sources for cloud credential retrieval: retrieved
secret values can enter saved state/plan files. If an existing organization requires
Vault, issue short-lived credentials outside Terraform and pass them through the
standard provider environment variables.

```powershell
aws sts get-caller-identity
az login
az account show
gcloud auth application-default login
```

Use only the intended subscription/project. The academic GCP/Azure environments may
be shared. Do not change project-wide IAM to resolve a deployment permission error.

## Restore Terraform state before deployment

The supplied original checkout lacked terraform.tfstate. An older saved plan is
incomplete, so its embedded snapshot is diagnostic evidence, not an authoritative
replacement. Locate a newer backup first. If none exists, inventory and import each
existing resource under the addresses in these modules. Imports record ownership in
state; they do not recreate resources. Do this in a separate recovery checkout with
a local backend, then review a refreshed plan for unexpected changes.

Important import targets:

| Terraform address | Existing resource identifier |
|---|---|
| module.aws.aws_s3_bucket.capstone | Existing capstone bucket name |
| module.aws.aws_s3_bucket_public_access_block.capstone | Same bucket name |
| module.aws.aws_s3_bucket_server_side_encryption_configuration.capstone | Same bucket name |
| module.aws_lambda.aws_lambda_function.capstone_api | multicloud-capstone-api |
| module.aws_lambda.aws_iam_role.lambda_execution | Actual execution role name from the Lambda configuration |
| module.aws_lambda.aws_iam_role_policy_attachment.basic_execution | Actual role name / AWSLambdaBasicExecutionRole policy ARN |
| module.aws_lambda.aws_lambda_function_url.capstone_api | multicloud-capstone-api |
| module.azure.azurerm_resource_group.capstone | Existing resource group ARM ID |
| module.azure.azurerm_container_registry.capstone | Existing ACR ARM ID |
| module.azure.azurerm_container_app_environment.capstone | Existing environment ARM ID |
| module.azure.azurerm_user_assigned_identity.acr_pull | Existing identity ARM ID |
| module.azure.azurerm_role_assignment.acr_pull | Existing AcrPull assignment ARM ID |
| module.azure.azurerm_container_app.capstone | Existing Container App ARM ID |
| module.gcp.google_storage_bucket.capstone | Existing GCS bucket name |
| module.gcp.google_cloud_run_v2_service.capstone | projects/PROJECT/locations/REGION/services/multicloud-capstone |

Also import S3 bucket versioning if already managed elsewhere. Do not import shared
resources into two states. Confirm region: S3 defaults to us-east-1, Lambda uses the
preserved ap-south-1 provider alias.

For the included S3 backend, choose a private existing bucket and the key
capstone/dev.tfstate, with encryption, versioning and least-privilege access to that
prefix. Keep a private backup of the recovered state. Initialize with bucket/region,
encrypt=true and use_lockfile=true; use init -migrate-state from the authoritative
local checkout. Review the interactive migration prompt. Never start CI from an
empty state against already deployed resources.

The deployment workflow checks that remote state exists. Configure a lifecycle for
the plans/ prefix (for example one-day expiry, including noncurrent versions) in a
state-only bucket, or a prefix-scoped rule in an existing bucket. Do not expire state.

## Existing workload release

Build the same app image, push it to existing ACR and Artifact Registry repositories,
and use each registry's digest reference for azure_image/gcp_image. Do not add ECR:
AWS uses a ZIP Lambda deployment, so an ECR copy would be unused.

Terraform packages lambda_function.py and runtime_metrics.py at the ZIP root.
The publish workflow also produces that ZIP. Keep the archived source and Terraform
source at the same commit. Review plan changes before applying; reject unexpected
deletions, replacements, shared IAM changes and new paid services.

Keep enable_global_routing=false and enable_backup_storage=false for the agreed
existing-resource path. Enabling global routing adds paid Front Door and a public
AWS GET API; it is not part of the current deployment authorization.

## Local live routing

Set AWS_FUNCTION_URL, AZURE_SERVICE_URL and GCP_SERVICE_URL to actual outputs.
Use AWS_REGION=ap-south-1. Start the router:

```powershell
$env:ENABLE_SIMULATION="true"
.venv\Scripts\python app/router.py
```

It binds to 127.0.0.1:8090. Capture /status and several / requests with
X-Selected-Cloud. Mark one cloud down using /simulate/aws/down, verify another
healthy cloud serves traffic, then restore /simulate/aws/up. Repeat for Azure/GCP.
Disable simulation outside the demonstration. All-down returns 503; failures after
a successful health probe retry another candidate. This entry point is local and
not highly available; do not claim it is production global DNS failover.

## Monitoring

Copy monitoring/.env.example to monitoring/.env, fill actual endpoint URLs and a
random Grafana admin password. Do not commit this file. Create monitoring/data/.

For local CLI/SSO credentials, run the exporter on the host:

```powershell
$env:AZURE_SERVICE_URL="https://YOUR-EXISTING-ENDPOINT"
$env:BILLING_FILE="monitoring/data/billing.json"
$env:BACKUP_SUCCESS_FILE="monitoring/data/backup-success.json"
.venv\Scripts\python -m scripts.monitor
```

In a second terminal:

```powershell
docker compose --env-file monitoring/.env -f monitoring/compose.yml -f monitoring/compose.host.yml up -d prometheus grafana alertmanager
```

Grafana: http://localhost:3000 (admin and the local .env password).
Prometheus: http://localhost:9090. Alertmanager: http://localhost:9093.
Dashboard title: Multi-Cloud Capstone. Data is sampled process/endpoint telemetry,
not an aggregation of every serverless replica. Cumulative CPU values may reset or
switch replicas and must not be represented as fleet CPU utilization.

The default receiver keeps alerts local. To enable Slack, save the user-owned incoming
webhook URL in monitoring/data/slack-webhook and add -f monitoring/compose.slack.yml.
That starts external notifications. Capture both a firing and a resolved test.
The webhook file must be readable by the Alertmanager container, never world-published.

Refresh billing using scripts.collect_costs and an edited cost-config.example.json.
It only reads existing billing sources. The GCP collector needs an existing BigQuery
billing export and caps scanned bytes; it does not create one. Set budget currency
to each account's currency. The AWS default is account-wide spend; use its optional
filter field for activated project tags. Describe scope accurately.

When academic billing permissions are unavailable, enter verified portal figures in
billing.json with a timestamp, per-cloud actual/budget/currency and source attribution.
Missing billing data remains stale, rather than showing invented zero spend.
Do not compare costs in different currencies as if they were equivalent.

## CI/CD configuration

Set main as GitHub's default branch. PR checks need no cloud secrets.
Create dev-plan, dev-apply, dev-publish and (only if used) dev-backup environments.
Restrict deployments to main and require a reviewer for dev-apply.

Use environment-specific AWS_ROLE_ARN, AZURE_CLIENT_ID, AZURE_TENANT_ID,
AZURE_SUBSCRIPTION_ID, GCP_WORKLOAD_IDENTITY_PROVIDER and GCP_SERVICE_ACCOUNT.
Trust only this repository's exact environment subject and required audience.
Plan identities need infrastructure reads plus state locking/private plan uploads.
Apply identities need writes only to capstone resources. Publish identities need
ACR push / Artifact Registry writer; backup identities need only backup-prefix object
read/write and the database's read role. Do not use Owner/Administrator shortcuts.

Set TF_STATE_BUCKET and TF_STATE_REGION. TF_CONFIG_JSON holds non-secret Terraform
inputs, including actual project, bucket, ACR names and explicit false extension flags.
Keep image digests in that configuration after release so later plans do not revert
to the original demo images. Pass input overrides only for deliberate new releases.

Publishing additionally uses ACR_NAME, GAR_HOST and GAR_REPOSITORY (full existing
repository path). Run publish, inspect digest metadata, then run deployment in plan
mode. The apply job uses the exact privately stored plan and Lambda ZIP after approval.
Plan bytes can contain secrets and are not uploaded as public Actions artifacts.

## Troubleshooting

- Azure token error: repeat az login in this user's environment.
- Cloud endpoint timeout: allow for scale-to-zero cold start, then check revisions/logs.
  Repeated outages must not be hidden by simply increasing timeouts.
- /metrics returns 404: the older application image/ZIP is still deployed.
- Terraform proposes existing Lambda/ACR creation: state is missing or incomplete; stop.
- Registry pull failure: verify the existing managed identity's scoped pull role.
- Grafana has no data: inspect Prometheus targets and exporter logs; host mode requires
  host.docker.internal to reach port 9108.
- Backup restore checksum mismatch: reject the replica and try another immutable backup.
- CI workflow absent from UI: check the default branch and workflow presence on main.
