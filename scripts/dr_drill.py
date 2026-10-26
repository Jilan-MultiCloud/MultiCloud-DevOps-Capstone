"""Run a real PostgreSQL backup/restore drill with LOCAL simulated cloud stores.

Docker is required. This does not provision or change any cloud resource.
Two uniquely named temporary containers are removed on completion.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
import uuid
from scripts.backup_restore import backup, restore, Store


class DirectoryStore:
    """Local test adapter, deliberately distinct from real cloud Store."""
    def __init__(self, root):
        self.root = Path(root)

    def put(self, key, path):
        target = self.root / key
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(Path(path).read_bytes())

    def get(self, key, path):
        Path(path).write_bytes((self.root / key).read_bytes())


def docker(*args, data=None):
    return subprocess.run(["docker", *args], input=data, capture_output=True,
                          check=True, timeout=180).stdout


def ready(name):
    for _ in range(60):
        try:
            docker("exec", name, "pg_isready", "-U", "postgres")
            return
        except subprocess.CalledProcessError:
            time.sleep(1)
    raise TimeoutError("PostgreSQL startup failed")


def sql(name, query, database="postgres"):
    return docker("exec", name, "psql", "-U", "postgres", "-d", database,
                  "-At", "-v", "ON_ERROR_STOP=1", "-c", query).decode().strip()


def drill(cloud_providers=None):
    suffix = uuid.uuid4().hex[:10]
    source, target = "capstone-source-" + suffix, "capstone-restore-" + suffix
    started = datetime.now(timezone.utc).isoformat()
    old_password = os.environ.get("POSTGRES_PASSWORD")
    os.environ["POSTGRES_PASSWORD"] = secrets.token_urlsafe(24)
    containers = []
    try:
        for name in (source, target):
            docker("run", "-d", "--name", name, "--network", "none",
                   "-e", "POSTGRES_PASSWORD", "postgres:16")
            containers.append(name)
            ready(name)
        sql(source, "CREATE TABLE capstone_data(id int PRIMARY KEY, value text); "
                    "INSERT INTO capstone_data VALUES (1,'aws'),(2,'azure'),(3,'gcp');")
        fingerprint = "SELECT md5(string_agg(id::text || ':' || value, ',' ORDER BY id)) FROM capstone_data"
        expected = sql(source, fingerprint)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dump = root / "source.dump"
            dump.write_bytes(docker("exec", source, "pg_dump", "-U", "postgres",
                                    "-d", "postgres", "--format=custom", "--no-owner", "--no-acl"))
            stores = ({cloud: Store(cloud) for cloud in cloud_providers} if cloud_providers
                      else {cloud: DirectoryStore(root / cloud) for cloud in ("aws", "azure", "gcp")})
            backup_id = "drill_" + uuid.uuid4().hex
            manifest = backup(dump, list(stores.values()), backup_id)
            # Make the loss window visible: this row is newer than the snapshot.
            sql(source, "INSERT INTO capstone_data VALUES(4,'after-backup');")
            docker("stop", source)
            dump.unlink()
            results = {}
            for cloud, store in stores.items():
                timer = time.monotonic()
                recovered = root / f"{cloud}.dump"
                restore(store, backup_id, recovered)
                database = "restore_" + cloud
                sql(target, f"CREATE DATABASE {database}")
                docker("exec", "-i", target, "pg_restore", "-U", "postgres",
                       "-d", database, "--no-owner", "--no-acl", "--exit-on-error",
                       data=recovered.read_bytes())
                actual = sql(target, fingerprint, database)
                count = int(sql(target, "SELECT count(*) FROM capstone_data", database))
                if actual != expected or count != 3:
                    raise AssertionError(f"{cloud} restored data differs from snapshot")
                results[cloud] = {"integrity_verified": True, "restored_rows": count,
                                  "rows_after_snapshot_not_recovered": 1,
                                  "restore_seconds": round(time.monotonic() - timer, 3)}
        scope = ("local PostgreSQL; real cloud object storage: " + ",".join(cloud_providers)
                 if cloud_providers else "local PostgreSQL; simulated cloud storage")
        return {"started_at": started, "scope": scope, "backup_id": backup_id,
                "source_stopped_before_restore": True, "backup_sha256": manifest["sha256"],
                "replicas": results,
                "limitation": "Local timings are not measured cloud RTO/RPO."}
    finally:
        for name in containers:
            subprocess.run(["docker", "rm", "-f", name], capture_output=True, timeout=60)
        if old_password is None:
            os.environ.pop("POSTGRES_PASSWORD", None)
        else:
            os.environ["POSTGRES_PASSWORD"] = old_password


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cloud-stores", nargs="+", choices=["aws", "azure", "gcp"],
                        help="Explicitly upload the sample dump to existing private cloud storage")
    args = parser.parse_args()
    report = drill(args.cloud_stores)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
