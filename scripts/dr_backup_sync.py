#!/usr/bin/env python3
"""Multi-cloud backup replication and disaster-recovery drill (Sprint 4).

  python scripts/dr_backup_sync.py backup  <file>   # replicate <file> to AWS, GCP and Azure
  python scripts/dr_backup_sync.py restore          # restore latest GCP replica and verify it

Each replica stores the file's SHA-256 as object metadata. `restore` downloads
the newest replica from a secondary cloud and compares the downloaded bytes with
that recorded checksum, so corruption during replication is actually detected.

Credentials come from the normal SDK chains (AWS CLI/env, `gcloud auth
application-default login`, AZURE_STORAGE_CONNECTION_STRING). Nothing is hardcoded.

Environment:
  AWS_DR_BUCKET   S3 bucket (see terraform output aws_dr_bucket_name)
  GCP_DR_BUCKET   GCS bucket (default: the Terraform-managed bucket)
  AZURE_DR_CONTAINER  Azure container (default: dr-backups)
"""
import hashlib
import os
import sys
import time

AWS_BUCKET = os.getenv("AWS_DR_BUCKET", "")
GCP_BUCKET = os.getenv("GCP_DR_BUCKET", "multicloud-capstone-storage-jilan-2026")
AZURE_CONTAINER = os.getenv("AZURE_DR_CONTAINER", "dr-backups")
RESTORE_DIR = os.getenv("RESTORE_DIR", "/tmp/multicloud_restore")
PREFIX = "dr-replicas/"


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def replicate_to_aws(path, name, checksum):
    import boto3

    if not AWS_BUCKET:
        print("[-] AWS skipped: set AWS_DR_BUCKET")
        return False
    boto3.client("s3").upload_file(
        path, AWS_BUCKET, PREFIX + name, ExtraArgs={"Metadata": {"sha256": checksum}}
    )
    print(f"[+] AWS  s3://{AWS_BUCKET}/{PREFIX}{name}")
    return True


def replicate_to_gcp(path, name, checksum):
    from google.cloud import storage

    blob = storage.Client().bucket(GCP_BUCKET).blob(PREFIX + name)
    blob.metadata = {"sha256": checksum}
    blob.upload_from_filename(path)
    print(f"[+] GCP  gs://{GCP_BUCKET}/{PREFIX}{name}")
    return True


def replicate_to_azure(path, name, checksum):
    conn = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
    if not conn:
        print("[-] Azure skipped: set AZURE_STORAGE_CONNECTION_STRING")
        return False
    from azure.storage.blob import BlobServiceClient

    blob = BlobServiceClient.from_connection_string(conn).get_blob_client(
        AZURE_CONTAINER, PREFIX + name
    )
    with open(path, "rb") as handle:
        blob.upload_blob(handle, overwrite=True, metadata={"sha256": checksum})
    print(f"[+] Azure {AZURE_CONTAINER}/{PREFIX}{name}")
    return True


def backup(path):
    if not os.path.isfile(path):
        sys.exit(f"[-] File not found: {path}")
    checksum = sha256_of(path)
    name = f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}-{os.path.basename(path)}"
    print(f"[*] Replicating {path} (sha256 {checksum})")

    results = {}
    for cloud, fn in (
        ("aws", replicate_to_aws),
        ("gcp", replicate_to_gcp),
        ("azure", replicate_to_azure),
    ):
        try:
            results[cloud] = fn(path, name, checksum)
        except Exception as exc:  # keep going so one cloud outage does not stop the rest
            print(f"[-] {cloud} failed: {type(exc).__name__}: {exc}")
            results[cloud] = False

    ok = [c for c, done in results.items() if done]
    print(f"[*] Replicated to {len(ok)}/3 clouds: {', '.join(ok) or 'none'}")
    if len(ok) < 2:
        sys.exit("[-] Need at least two clouds for redundancy")


def restore():
    from google.cloud import storage

    os.makedirs(RESTORE_DIR, exist_ok=True)
    print(f"[*] Failing over to secondary cloud: GCP bucket {GCP_BUCKET}")
    blobs = list(storage.Client().bucket(GCP_BUCKET).list_blobs(prefix=PREFIX))
    if not blobs:
        sys.exit("[-] No backup replicas found in secondary provider storage")

    latest = max(blobs, key=lambda b: b.time_created)
    expected = (latest.metadata or {}).get("sha256")
    local = os.path.join(RESTORE_DIR, os.path.basename(latest.name))
    latest.download_to_filename(local)
    print(f"[+] Downloaded {latest.name} -> {local}")

    actual = sha256_of(local)
    if not expected:
        sys.exit("[-] Replica has no recorded sha256 metadata; cannot verify integrity")
    if actual != expected:
        sys.exit(f"[-] INTEGRITY FAILURE: expected {expected}, got {actual}")

    size_mb = os.path.getsize(local) / (1024 * 1024)
    print(f"[+] Integrity verified (sha256 {actual}); restored {size_mb:.2f} MB")
    print("[+] DR drill passed")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "backup":
        backup(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == "restore":
        restore()
    else:
        sys.exit(__doc__)
