import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("links", Path(__file__).resolve().parents[1] / "scripts/links.py")
links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(links)


class LinkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()

    def tearDown(self):
        self.output.__exit__(None, None, None)
        self.tmp.cleanup()

    def test_backup_idempotence_restore_and_rime_isolation(self):
        original = self.home / ".zprofile"
        original.write_text("original\n")
        rime = self.home / "Library/Rime"
        rime.mkdir(parents=True)
        learned = rime / "user.yaml"
        learned.write_text("local data\n")
        links.install(self.home, False)
        self.assertEqual(links.status(self.home), 0)
        links.install(self.home, False)
        manifests = list(self.home.glob(".local/state/dotfiles/backups/*/manifest.json"))
        self.assertEqual(len(manifests), 1)
        self.assertEqual(learned.read_text(), "local data\n")
        self.assertFalse(rime.is_symlink())
        links.restore(manifests[0], False)
        self.assertFalse(original.is_symlink())
        self.assertEqual(original.read_text(), "original\n")
        self.assertFalse((self.home / ".zshrc").exists())

    def test_dry_run_has_no_writes(self):
        links.install(self.home, True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_restore_protects_replaced_files(self):
        links.install(self.home, False)
        changed = self.home / ".zshrc"
        changed.unlink()
        changed.write_text("changed\n")
        manifest = next(self.home.glob(".local/state/dotfiles/backups/*/manifest.json"))
        with self.assertRaises(RuntimeError):
            links.restore(manifest, False)
        self.assertEqual(changed.read_text(), "changed\n")
        self.assertTrue((self.home / ".zprofile").is_symlink())

    def test_symlink_parent_rejected(self):
        target = self.home / "elsewhere"
        target.mkdir()
        (self.home / "Library").symlink_to(target)
        with self.assertRaises(RuntimeError):
            links.install(self.home, False)
        self.assertFalse((self.home / ".zprofile").exists())

    def test_dangling_link_is_backed_up(self):
        dest = self.home / ".zshrc"
        dest.symlink_to("missing-original")
        links.install(self.home, False)
        manifest = next(self.home.glob(".local/state/dotfiles/backups/*/manifest.json"))
        links.restore(manifest, False)
        self.assertEqual(dest.readlink(), Path("missing-original"))
