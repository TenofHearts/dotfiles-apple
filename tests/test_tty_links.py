from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GHOSTTY = Path("Library/Application Support/com.mitchellh.ghostty")
KITTY = Path(".config/kitty")


class TerminalLinkTests(unittest.TestCase):
    def cli(self, home, action, app, *options, expected=0):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/links.py"), action, "--home", str(home),
             "--only", app, *options], capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_terminal_selections_install_and_inspect_only_their_own_files(self):
        ghostty = {GHOSTTY / "config.ghostty": "config/ghostty/config.ghostty",
                   GHOSTTY / "tty.ghostty": "config/tty/ghostty/config.ghostty",
                   GHOSTTY / "cursor_tail.glsl": "config/tty/ghostty/cursor_tail.glsl"}
        kitty = {KITTY / "kitty.conf": "config/tty/kitty/kitty.conf"}
        for app, files, other in (("ghostty", ghostty, KITTY), ("kitty", kitty, GHOSTTY)):
            with self.subTest(app=app), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp) / "home"
                self.cli(home, "install", app, "--dry-run")
                self.assertFalse(home.exists())
                self.cli(home, "install", app)
                self.assertFalse((home / other).exists())
                self.assertEqual({p.relative_to(home) for p in home.rglob("*") if p.is_symlink()}, set(files))
                for dest, source in files.items():
                    self.assertTrue((home / dest).is_file())
                    self.assertEqual((home / dest).resolve(), ROOT / source)
                status = self.cli(home, "status", app)
                self.assertEqual(set(status.stdout.splitlines()), {f"OK {home / dest}" for dest in files})
                self.assertIn("No configuration links to install", self.cli(home, "install", app).stdout)

    def test_aggregate_selectors_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            for app in ("tty", "shell"):
                with self.subTest(app=app):
                    self.cli(home, "install", app, expected=2)
                    self.assertFalse(home.exists())

    def test_kitty_conflicts_are_isolated_from_ghostty(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            external = Path(tmp) / "elsewhere"
            external.mkdir()
            kitty_dir = home / KITTY
            kitty_dir.parent.mkdir(parents=True)
            kitty_dir.symlink_to(external, target_is_directory=True)
            result = self.cli(home, "install", "kitty", "--force", expected=1)
            self.assertIn("Symlinked parent needs manual review", result.stderr)
            self.assertFalse((home / "Library").exists())
            self.cli(home, "install", "ghostty", "--force")
            self.cli(home, "status", "ghostty")
            self.assertEqual(list(external.iterdir()), [])

            kitty_dir.unlink()
            kitty_dir.mkdir()
            config = kitty_dir / "kitty.conf"
            config.write_text("local settings\n")
            theme = kitty_dir / "themes/noctalia.conf"
            theme.parent.mkdir()
            theme.write_text("local theme\n")
            self.cli(home, "install", "kitty")
            self.cli(home, "status", "kitty", expected=1)
            self.assertEqual(config.read_text(), "local settings\n")
            self.cli(home, "install", "kitty", "--force")
            self.cli(home, "status", "kitty")
            self.assertEqual(theme.read_text(), "local theme\n")
