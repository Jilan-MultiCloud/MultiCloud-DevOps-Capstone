# Multi-Cloud Deployment and Management with Terraform

An individual DevOps capstone project demonstrating Infrastructure as Code across AWS, Microsoft Azure, and Google Cloud Platform (GCP), with a focus on cost control, repeatability, availability, recovery, and monitoring.

> **Cost and safety first:** this starter does not create cloud resources. Review every `terraform plan` before applying changes. Cloud services can incur charges even when lightly used. Set budget alerts in each cloud console and destroy temporary infrastructure after demonstrations.

## Project goals

- Manage AWS, Azure, and GCP infrastructure with Terraform.
- Organize provider-specific resources into reusable modules.
- Demonstrate application health checks and cross-cloud DNS failover.
- Document backup, restore, and disaster-recovery testing.
- Add monitoring, alerting, CI validation, and cost-management guidance.

## Repository layout

```text
.
├── .github/workflows/terraform-checks.yml
├── terraform/
│   ├── environments/dev/
│   │   ├── versions.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── modules/
│       ├── aws/.gitkeep
│       ├── azure/.gitkeep
│       └── gcp/.gitkeep
├── app/
├── monitoring/
├── scripts/
├── docs/
├── .gitignore
└── README.md
```

## Prerequisites

- Windows with VS Code and PowerShell
- Git
- Terraform CLI
- Cloud accounts/subscriptions/projects for AWS, Azure, and GCP
- Provider CLIs for local authentication when needed: AWS CLI, Azure CLI, and Google Cloud CLI

## Initial local checks

From the repository root:

```powershell
cd terraform/environments/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

The initial configuration contains provider declarations only, so `terraform plan` should not create resources. `terraform init` downloads provider plugins and writes `.terraform.lock.hcl`; commit that lock file for reproducibility.

## Authentication (local development)

Authenticate with your normal CLI login rather than putting credentials in `.tf` files.

### AWS

Configure the AWS CLI with a profile, then verify it:

```powershell
aws configure --profile capstone
aws sts get-caller-identity --profile capstone
$env:AWS_PROFILE = "capstone"
```

Use least-privilege IAM permissions. Avoid root-account access keys.

### Azure

```powershell
az login
az account show
```

If you have multiple subscriptions, select the intended one with `az account set --subscription "<SUBSCRIPTION_ID>"`.

### Google Cloud

```powershell
gcloud init
gcloud auth application-default login
gcloud config get-value project
```

Set the project ID for Terraform in the current PowerShell session:

```powershell
$env:TF_VAR_gcp_project_id = "YOUR_GCP_PROJECT_ID"
```

Do not commit credentials, service-account keys, `.env` files, Terraform state, or real `.tfvars` files. Use a secret manager or CI identity federation for later automation.

## Cost-control checklist

1. Create budget alerts in AWS, Azure, and GCP before provisioning.
2. Prefer small, short-lived demo resources and free/low-cost options only after confirming regional eligibility and pricing.
3. Avoid NAT gateways, managed Kubernetes, cross-region replication, managed databases, and premium load balancers unless the demo truly requires them; these can add recurring charges.
4. Check egress, public IPv4, disks, snapshots, DNS, logs, and monitoring costs as well as compute.
5. Run `terraform plan` and review every proposed resource before `terraform apply`.
6. Keep a resource inventory and capture evidence for the report.
7. After a test, run `terraform destroy` from the same environment directory and confirm the resources are gone. Backups and some external resources may need separate cleanup.
8. Budget alerts are notifications, not automatic spending caps.

## Planned sprints

1. Repository foundation, provider setup, authentication and security.
2. Minimal resources in each cloud and reusable modules.
3. Application health checks and DNS failover.
4. Backup, restore and disaster-recovery test.
5. Monitoring, alerts and cost reporting.
6. CI/CD, final test evidence, documentation and viva preparation.

## Current status

- [x] Repository scaffold and Terraform provider declarations
- [ ] Authenticate to all three providers
- [ ] Deploy a minimal resource in each provider
- [ ] Demonstrate cross-cloud failover
- [ ] Test backup/restore
- [ ] Monitoring and alerting
- [ ] CI/CD and final evidence

Update this checklist only when each item has actually been tested.
