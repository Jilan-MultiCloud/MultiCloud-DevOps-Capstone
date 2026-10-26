import json
from pathlib import Path
import tempfile
import unittest
from scripts.backup_restore import backup, restore


class MemoryStore:
    def __init__(self):
        self.objects = {}

    def put(self, key, path):
        self.objects[key] = Path(path).read_bytes()

    def get(self, key, path):
        Path(path).write_bytes(self.objects[key])


class BackupTests(unittest.TestCase):
    def test_restore_from_every_cloud_after_primary_loss(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.write_bytes(b"database dump\x00\xff")
            stores = [MemoryStore() for _ in range(3)]
            manifest = backup(source, stores, "drill")
            source.unlink()
            for index, store in enumerate(stores):
                target = Path(directory) / str(index)
                self.assertEqual(restore(store, "drill", target), manifest)
                self.assertEqual(target.read_bytes(), b"database dump\x00\xff")

    def test_corruption_and_existing_destination_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.write_bytes(b"good")
            store = MemoryStore()
            backup(source, [store], "drill")
            with self.assertRaises(FileExistsError):
                restore(store, "drill", source)
            store.objects["backups/drill/data"] = b"evil"
            target = Path(directory) / "restored"
            with self.assertRaises(ValueError):
                restore(store, "drill", target)
            self.assertFalse(target.exists())

    def test_manifest_mismatch_and_upload_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.write_bytes(b"good")
            store = MemoryStore()
            backup(source, [store], "drill")
            manifest = json.loads(store.objects["backups/drill/manifest.json"])
            manifest["backup_id"] = "other"
            store.objects["backups/drill/manifest.json"] = json.dumps(manifest).encode()
            with self.assertRaises(ValueError):
                restore(store, "drill", Path(directory) / "target")
            class BrokenStore(MemoryStore):
                def put(self, key, path):
                    raise OSError("unavailable")
            with self.assertRaises(OSError):
                backup(source, [store, BrokenStore()], "next")


if __name__ == "__main__":
    unittest.main()
