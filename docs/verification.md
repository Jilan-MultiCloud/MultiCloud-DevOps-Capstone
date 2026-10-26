# Verification evidence — 26 October 2026

## Passed

| Check | Result | Scope |
|---|---|---|
| Python unittest suite | 17 tests passed | HTTP routes, metrics format, routing retry/outage/recovery, corrupt-backup rejection, restored data, CI config, currencies and exporter behavior |
| Terraform formatting/validation | Passed | Locked provider schemas; no live infrastructure apply |
| Terraform tests | 2 passed | Mock plans with optional resources off/on |
| Docker application build | Passed | Python 3.12 container |
| GitHub workflow actionlint | Passed | Workflow syntax and shell analysis |
| Prometheus config/rules | Passed | Container and host-exporter configs; seven alert rules |
| Prometheus alert rule test | Passed | Outage fires and clears after recovery |
| Alertmanager local receiver | Passed | Configuration validation; no external notification |
| Local PostgreSQL drill | Passed | Source stopped; restore from three simulated stores; ordered data fingerprint verified |
| Real S3/GCS PostgreSQL snapshot drill | Passed | Existing cloud object stores; source local database stopped; both replicas restored into isolated local databases and verified |
| Live local routing drill | Passed | All three real cloud endpoints healthy; each exclusion routes to another cloud; all recover |
| Local Grafana/Prometheus stack | Passed | Provisioned six-panel dashboard, database health OK, exporter target up |

Evidence JSON files in [evidence/](evidence/) include UTC timestamps and explicit
scope labels. The test data is synthetic and contains no production records.

## Live routing results

| Locally excluded backend | Selected healthy backend | HTTP result |
|---|---|---|
| AWS | Azure | 200 |
| Azure | GCP | 200 |
| GCP | AWS | 200 |

The exclusion occurs in the local router. No cloud service was stopped. This proves
the local router's failover behavior against live backends; it does not prove global
DNS failover or provider-wide outage recovery.

## Database integrity results

The drill inserted three rows, took a snapshot, then inserted one more row and stopped
the source. Every restored database contained exactly the three snapshot rows with
the expected ordered fingerprint. The later row was intentionally absent.

For real cloud storage, the backup ID was
drill_e620a958ab0049218ecade34a643739c and the verified SHA-256 was
f44e8ef929e36530cbd7fb45dd22d4490f4e76f6fb83974cc614d6f867d66ec7.
S3 recovery took approximately 4.547 seconds and GCS recovery approximately 2.570
seconds in this small local-database exercise. These are measured exercise durations,
not production RTO guarantees. The local PostgreSQL restore target was not a managed
database in a second cloud.

## Still unverified or blocked

- Azure management authentication expired; a fresh sign-in is required.
- No current authoritative Terraform state was found in the supplied original folder.
  The saved plan's older snapshot omits existing Lambda/most Azure resources.
- Updated runtime metrics are implemented and tested locally but not deployed.
  Live /metrics currently reports unavailable in the dashboard.
- Real Azure blob replication and three-provider storage recovery remain pending.
- Slack delivery/resolution requires the user's webhook and an actual test.
- Actual billing collection requires billing permissions and an existing GCP export;
  no cost figures have been fabricated.
- Federated publishing/deployment environments and remote state need configuration.
- Managed global routing and extra Azure storage remain disabled under the user's
  existing-resources-only instruction.

Historical screenshots in docs/screenshots are retained as prior evidence. They are
not represented as results from the current release.
