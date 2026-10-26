# Disaster recovery and replication runbook

## Scope and recovery objectives

The current application is stateless. PostgreSQL supplies a separate example dataset
for demonstrating consistent database snapshots and recovery. The implementation uses
asynchronous pg_dump snapshots replicated to object storage, not synchronous database
replication or multi-writer database failover.

Proposed demonstration targets: RPO at most 24 hours for daily backups, and RTO under
30 minutes for a small dataset. These are objectives, not measured guarantees.
Measure them during the live exercise. A failed backup increases effective RPO, and
an unavailable restore target increases RTO.

RPO = incident time minus the timestamp of the latest recoverable committed snapshot.
RTO = incident declaration to a verified usable recovered service, including detection,
restore and endpoint switching. File download duration alone is not RTO.

## Local rehearsal (no cloud resources)

```powershell
python -m scripts.dr_drill --output recovery/local-postgres-drill.json
```

The drill starts two isolated local PostgreSQL 16 containers, writes three rows,
creates a real custom-format dump, stores/verifies three local copies, writes one
later row, stops the source, restores each copy into separate recovery databases,
and compares ordered row fingerprints. The post-snapshot row is intentionally absent.
This demonstrates why asynchronous snapshots have a nonzero data-loss window.
The JSON report explicitly labels the stores as simulated. Do not label this result
as proof of real AWS-to-GCP/Azure replication.

For a real-storage exercise after configuring the existing buckets, run
`python -m scripts.dr_drill --cloud-stores aws gcp --output recovery/remote-storage-drill.json`.
Add azure only when an authorized existing blob container is configured. This uploads
the synthetic dump and manifests to the selected existing stores. The report lists
which providers were actually verified. The source and restore database remain local.

## Live replication into existing storage

Use only authorized, existing private storage. Set:

- BACKUP_S3_BUCKET: existing project bucket; keys stay under backups/.
- BACKUP_GCS_BUCKET: existing project bucket.
- GOOGLE_CLOUD_PROJECT: the existing GCP project ID (required when ADC has no default project).
- BACKUP_AZURE_ACCOUNT_URL: existing blob service HTTPS endpoint.
- BACKUP_AZURE_CONTAINER: existing private container, normally backups.

Authenticate via AWS default credential chain, Azure DefaultAzureCredential and GCP
Application Default Credentials. Grant object read/write on the backup prefixes only.
The tool never creates a bucket/account/container or changes IAM. If no authorized
Azure storage exists, the three-cloud drill remains blocked under the existing-only
constraint; do not silently borrow another team's storage.

For a file snapshot:

```powershell
python -m scripts.backup_restore backup recovery/sample.json
```

For PostgreSQL, configure PGHOST, PGPORT, PGDATABASE, PGUSER, PGSSLMODE=verify-full
and PGSSLROOTCERT. Use a private PGPASSFILE or process-only PGPASSWORD, not command-line
passwords. The dump client must be compatible with the server version.

```powershell
python -m scripts.database_backup --success-file monitoring/data/backup-success.json
```

Success is reported only after all three uploads and remote-byte checksum checks.
The success marker includes the immutable backup ID. Keep manifests/dumps private.
The copy algorithm is streaming; it does not load a large database into memory.
Partial failure may leave orphaned objects; record failure and retry with a new ID.
There is no automatic retention deletion. Review backup retention and noncurrent
object versions before enabling routine backups.

The GitHub backup workflow is disabled unless ENABLE_BACKUP_AUTOMATION=true. It also
requires main as the default branch, scoped federated identities, an accessible
database with TLS trust, and existing storage. Its artifact contains metadata only.
Copy its verified timestamp to the local monitoring evidence file if monitoring runs
on a different host. Do not advance that timestamp merely because a schedule fired.

## Restore and integrity check

Select a replica in a cloud independent of the failed source:

```powershell
python -m scripts.backup_restore restore gcp BACKUP_ID recovery/restored.dump
```

The destination must not exist. The tool verifies manifest identity, byte count and
SHA-256 before writing the recovered file. A matching hash proves agreement with the
manifest; store access controls protect the manifest from unauthorized modification.

Restore into a NEW isolated database, never directly over the production database:

```text
createdb capstone_recovery
pg_restore --exit-on-error --no-owner --no-acl --dbname=capstone_recovery recovery/restored.dump
```

Run database-specific checks: row counts, ordered content hashes, primary/foreign keys,
known records and a read-only application smoke test. Credentials and TLS settings
must point to the intended recovery server. Record which records newer than the
snapshot are absent. Only switch the application database endpoint after checks pass.
The example HTTP app has no database dependency, so switching its web cloud does not
prove database failover.

## Failover, failback and evidence

1. Record UTC start time, active service, backup ID, commit and data fingerprint.
2. Record fault time. Use a reversible test failure on the selected demo workload;
   never stop/delete shared academic infrastructure.
3. Verify traffic selects another healthy backend through the local router.
4. Restore a replica, verify data and record the time a usable service is available.
5. Calculate measured RTO/RPO; keep screenshots/logs and distinguish local from cloud.
6. Recover the original service, verify health, then restore normal routing.
7. If the recovery database accepted writes, reconcile them before failback to avoid
   discarding new data. No automatic multi-writer reconciliation is implemented.

## Required live evidence

- Same backup ID and SHA-256 verified from AWS, Azure and GCP.
- Source unavailable while a secondary-cloud copy is restored.
- SQL verification output and representative application read.
- Timed outage, recovery and failback.
- Successful later backup after recovery.
- Alert firing and resolution.
