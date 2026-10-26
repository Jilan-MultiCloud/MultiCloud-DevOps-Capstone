"""Versioned file/database-dump replication with end-to-end integrity checks.

Credentials come from each SDK's default identity chain. No cloud credentials
are accepted in configuration files. A backup succeeds only after ALL stores
have acknowledged both data and manifest; partial uploads remain retryable.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import uuid
from datetime import datetime, timezone


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


class Store:
    def __init__(self, provider):
        self.provider = provider
        if provider == "aws":
            import boto3
            self.client = boto3.client("s3")
            self.bucket = os.environ["BACKUP_S3_BUCKET"]
        elif provider == "gcp":
            from google.cloud import storage
            self.client = storage.Client().bucket(os.environ["BACKUP_GCS_BUCKET"])
        elif provider == "azure":
            from azure.identity import DefaultAzureCredential
            from azure.storage.blob import BlobServiceClient
            url = os.environ["BACKUP_AZURE_ACCOUNT_URL"]
            self.client = BlobServiceClient(url, DefaultAzureCredential()).get_container_client(
                os.environ.get("BACKUP_AZURE_CONTAINER", "backups"))
        else:
            raise ValueError("Unsupported provider")

    def put(self, key, path):
        if self.provider == "aws":
            self.client.upload_file(str(path), self.bucket, key,
                                    ExtraArgs={"ServerSideEncryption": "AES256"})
        elif self.provider == "gcp":
            self.client.blob(key).upload_from_filename(str(path), if_generation_match=0)
        else:
            with open(path, "rb") as stream:
                self.client.upload_blob(key, stream, overwrite=False)

    def get(self, key, path):
        if self.provider == "aws":
            self.client.download_file(self.bucket, key, str(path))
        elif self.provider == "gcp":
            self.client.blob(key).download_to_filename(str(path))
        else:
            with open(path, "wb") as stream:
                self.client.download_blob(key).readinto(stream)


def validate_id(backup_id):
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", backup_id):
        raise ValueError("Invalid backup ID")


def backup(source, stores, backup_id):
    validate_id(backup_id)
    source = Path(source)
    manifest = {"version": 1, "backup_id": backup_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "sha256": sha256(source), "size": source.stat().st_size}
    with tempfile.TemporaryDirectory() as directory:
        metadata = Path(directory) / "manifest.json"
        metadata.write_text(json.dumps(manifest), encoding="utf-8")
        for store in stores:
            store.put(f"backups/{backup_id}/data", source)
            store.put(f"backups/{backup_id}/manifest.json", metadata)
            # Verify the actual remote bytes, not just an upload acknowledgement.
            replica = Path(directory) / "replica"
            store.get(f"backups/{backup_id}/data", replica)
            if sha256(replica) != manifest["sha256"]:
                raise ValueError("Remote replica checksum mismatch")
    return manifest


def restore(store, backup_id, destination):
    validate_id(backup_id)
    destination = Path(destination)
    if destination.exists():
        raise FileExistsError("Restore requires a new destination")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as directory:
        metadata = Path(directory) / "manifest.json"
        replica = Path(directory) / "data"
        store.get(f"backups/{backup_id}/manifest.json", metadata)
        manifest = json.loads(metadata.read_text(encoding="utf-8"))
        if manifest.get("version") != 1 or manifest.get("backup_id") != backup_id:
            raise ValueError("Manifest identity/version mismatch")
        store.get(f"backups/{backup_id}/data", replica)
        if replica.stat().st_size != manifest["size"] or sha256(replica) != manifest["sha256"]:
            raise ValueError("Restore integrity check failed")
        # Exclusive creation also protects against a destination appearing mid-restore.
        with destination.open("xb") as output, replica.open("rb") as source:
            import shutil
            shutil.copyfileobj(source, output)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    upload = sub.add_parser("backup")
    upload.add_argument("source", type=Path)
    download = sub.add_parser("restore")
    download.add_argument("provider", choices=["aws", "azure", "gcp"])
    download.add_argument("backup_id")
    download.add_argument("destination", type=Path)
    args = parser.parse_args()
    if args.command == "backup":
        backup_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ_") + uuid.uuid4().hex
        result = backup(args.source, [Store(p) for p in ("aws", "azure", "gcp")], backup_id)
    else:
        result = restore(Store(args.provider), args.backup_id, args.destination)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
