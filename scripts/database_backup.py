"""Snapshot PostgreSQL and verify replicas on existing cloud storage.

Use PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD/PGPASSFILE and PGSSLMODE.
The source database is read only. pg_dump must match the server major version
or be newer. The dump is never uploaded as a GitHub workflow artifact.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
from scripts.backup_restore import backup, Store


def run_backup(success_file=None):
    if not os.environ.get("PGDATABASE") or not os.environ.get("PGHOST"):
        raise ValueError("PGDATABASE and PGHOST are required")
    with tempfile.TemporaryDirectory() as directory:
        dump = Path(directory) / "database.dump"
        subprocess.run(["pg_dump", "--format=custom", "--no-owner", "--no-acl",
                        "--file", str(dump)], check=True, capture_output=True)
        manifest = backup(dump, [Store(p) for p in ("aws", "azure", "gcp")],
                          "postgres_" + uuid.uuid4().hex)
    if success_file:
        target = Path(success_file)
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_suffix(".tmp")
        temporary.write_text(json.dumps({"timestamp": time.time(),
                                         "backup_id": manifest["backup_id"]}), encoding="utf-8")
        temporary.replace(target)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--success-file", type=Path)
    args = parser.parse_args()
    print(json.dumps(run_backup(args.success_file)))
