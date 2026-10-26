# Capstone review and completion tracker

Review date: 26 October 2026. Submission deadline: 31 October 2026.
Baseline: main commit 8b5ad04. Constraint: use existing cloud resources only.

## Assessment

The baseline demonstrates serverless workloads in three clouds, reusable Terraform
modules and a local two-cloud router. It does not establish production-grade global
availability, database recovery, operational monitoring or an automated deployment.
This change supplies the missing code and repeatable checks, but live account setup
and evidence remain separate acceptance gates. Do not describe code-only features as
already deployed.

| Requirement | Baseline gap | Added implementation | Acceptance evidence still required |
|---|---|---|---|
| Sprint 1: repository, providers, secure access | Latest providers.tf duplicates versions.tf, conflicts with locked Azure/GCP versions, omits aws.mumbai and reads long-lived secrets into Terraform | One provider/version definition; preserved Mumbai alias; CLI credentials and OIDC workflows; environment-specific permissions guidance | Renew Azure login; configure GitHub federated identities and protected environments |
| Sprint 2: modular infrastructure in AWS/Azure/GCP | Existing modules and serverless endpoints; image references not release parameters | Parameterized release images; packaged Lambda helper; versioned S3/GCS storage; private optional Azure storage | Restore authoritative state and review a no-replacement plan; redeploy metrics code |
| Sprint 2: secure communication | HTTPS cloud endpoints; IAM-protected Lambda; no cross-cloud private network | Existing TLS and Lambda signing preserved | Document public HTTPS as the chosen demo network design; a private network is not implemented |
| Sprint 3: routing, load balancing, health checks | Local router only supports AWS/GCP; no managed global entry point | Three-cloud round-robin routing, health selection, retry after backend failure, tested live exclusion/recovery drill; optional Front Door/API Gateway module | Managed global routing stays OFF under existing-resources constraint |
| Sprint 3: DNS routing | No Route 53/Cloud DNS routing | Optional managed edge endpoint with provider host headers and TLS validation | Custom DNS and production edge deployment remain unimplemented/unverified; do not claim DNS failover |
| Sprint 4: cross-cloud replication | Empty scripts folder; no database or backup process | Streaming SDK upload/download, snapshot manifests, SHA-256 verification, PostgreSQL automation; real S3/GCS sample recovery verified | Azure private storage/access and three-provider verification; an actual managed-database recovery target |
| Sprint 4: recovery and consistency | No recovery tests or RPO/RTO evidence | Real local PostgreSQL source-stop/restore drill; corrupted replicas rejected; runbook and evidence format | Measure cloud RPO/RTO and verify application behavior after real restore |
| Sprint 5: Prometheus/Grafana | Prometheus scraped missing /metrics endpoints; no running dashboard | Runtime metrics, authenticated cloud probes, provisioned dashboard and local Compose stack | Deploy /metrics to existing workloads; capture real dashboard data |
| Sprint 5: resource alerts | Rules referenced counters that were not emitted | Memory-budget, outage, metrics/exporter failure and backup-staleness alerts | Demonstrate a firing and resolved incident |
| Sprint 5: Slack/PagerDuty | No receiver configuration | Optional Slack receiver using a mounted webhook secret; local receiver by default | User-owned webhook and a delivered/resolved test message |
| Sprint 5: cost optimization | Prose only | Billing collectors for existing AWS/Azure/GCP billing sources, currency-aware budget dashboard, stale-data alerts, cost worksheet | Billing access/export availability, actual spend and chosen thresholds; budgets are not spending caps |
| Sprint 6: CI/CD | Workflow builds Docker Hub image, does not deploy; weak PR coverage | PR checks, ACR/GAR release publishing, Lambda ZIP artifact, OIDC plan/apply with private plan storage | Configure remote state and protected environments; run approved deployment |
| Sprint 6: documentation/viva | README and historical screenshots only | Setup, recovery, security/state recovery, submission report, viva and final checklist | Add current dated screenshots, stakeholder feedback and final demonstrated results |

## Important findings

1. **State is missing from the supplied original folder.** The committed tfplan contains
   an older snapshot with six managed resources and one data source. It omits the live
   Lambda and most Azure resources. Applying from that snapshot would propose duplicate
   resources. Reconstruct state with imports after inventory; never apply blindly.
2. **The default GitHub branch was master, with an empty tree.** Use main for submission
   and configure main as the default branch before expecting scheduled/manual workflows.
3. **Generated provider files and a saved plan were committed.** They are removed from
   the new tree and ignored. Removing files does not erase Git history. Review historic
   plan contents privately for credentials; rotate only if actual secret exposure is found.
4. **The baseline home/404 screenshots share identical image content.** Capture fresh,
   distinct successful home and expected-404 results; do not reuse mislabeled evidence.
5. **Serverless alternatives need an explicit scope explanation.** Lambda, Container Apps
   and Cloud Run replace the example VMs. Platform-managed ingress replaces per-cloud
   VM load balancers. This is a cost-conscious design choice, not proof that every
   literal infrastructure example in the brief has been deployed.

## Completion rule

Mark a requirement complete only when its code, applicable checks and live evidence are
available. Under the existing-resources-only constraint, a local router is a single
point of failure and the local PostgreSQL drill does not establish cross-cloud DR.
These limitations must remain visible in the report and viva.
