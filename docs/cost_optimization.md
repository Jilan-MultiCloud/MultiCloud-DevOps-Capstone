# Cost Optimization

| Area | Measure |
|---|---|
| Compute | Lambda pay-per-request; Cloud Run and Container Apps scale to zero (`min_instances = 0`) |
| Container registries | ECR keeps the last 5 images (lifecycle policy); ACR uses the Basic tier |
| Storage | DR S3 bucket expires non-current versions after 30 days and aborts stale multipart uploads |
| Networking | No NAT gateways, load balancers or managed Kubernetes; Route 53 failover uses 2 health checks only |
| Monitoring | Probes run every 30 s from a local Prometheus stack (no paid monitoring service) |
| CI | Docker layer cache (`type=gha`); image built once and pushed to all registries |

## Budget alerts (set once per cloud)

- AWS: Billing > Budgets > monthly cost budget with an 80 % email alert.
- Azure: Cost Management > Budgets with an 80 % alert on the resource group `rg-multicloud-capstone-dev`.
- GCP: Billing > Budgets & alerts on the project.

Budgets send notifications; they do not stop spending.

## Cost review checklist

1. `terraform plan` before every apply, checking for new always-on resources.
2. Weekly look at each provider's cost explorer.
3. Delete unused images and old backups; never delete shared academic resources.
