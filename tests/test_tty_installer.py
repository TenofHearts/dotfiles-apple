import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class TtyInstallerTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.log = self.tmp / "commands"
        self.env = {**os.environ, "HOME": str(self.tmp / "home"), "PATH": str(self.bin),
                    "COMMAND_LOG": str(self.log)}
        (self.bin / "dirname").symlink_to("/usr/bin/dirname")
        (self.bin / "python3").symlink_to(sys.executable)
        self.stub("uname", "echo Darwin")
        self.stub("git", '''printf '%s\\n' "$0" "$@" >> "$COMMAND_LOG"''')
        for name in ("brew", "xcode-select", "curl", "rustup", "lua"):
            self.stub(name, '''echo "$0" >> "$COMMAND_LOG"; exit 97''')

    def stub(self, name, body):
        command = self.bin / name
        command.write_text(f"#!/bin/sh\n{body}\n")
        command.chmod(0o755)

    def invoke(self, script, *args):
        return subprocess.run([ROOT / script, *args], cwd=self.tmp, env=self.env,
                              capture_output=True, text=True)

    def test_only_initializes_tty_and_links_selected_terminals(self):
        ghostty = Path("Library/Application Support/com.mitchellh.ghostty")
        kitty = Path(".config/kitty")
        for selection, directory in (("ghostty", ghostty), ("kitty", kitty)):
            with self.subTest(selection=selection):
                home = self.tmp / selection
                result = self.invoke("install.sh", "--only", selection, "--home", home)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.log.read_text().splitlines(), [str(self.bin / "git"), "-C",
                                 str(ROOT), "submodule", "update", "--init", "--recursive", "--", "config/tty"])
                self.log.unlink()
                linked = {p.relative_to(home).parent for p in home.rglob("*") if p.is_symlink()}
                self.assertEqual(linked, {directory})

    def test_previews_and_invalid_arguments_do_not_start_setup(self):
        for script, args, code, message in (
            ("install.sh", ["--only=kitty", "--dry-run"], 0, "kitty.conf"),
            ("install.sh", ["--only=ghostty", "--bootstrap"], 2, "./scripts/bootstrap.sh"),
            ("install.sh", ["--only=tty"], 2, "Unknown app: tty"),
            ("install.sh", ["--only=shell"], 2, "Unknown app: shell"),
            ("scripts/bootstrap.sh", ["--dry-run"], 0, "Brewfile"),
            ("scripts/bootstrap.sh", ["--only=kitty"], 2, "Unknown argument"),
        ):
            with self.subTest(script=script, args=args):
                result = self.invoke(script, *args)
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertIn(message, result.stdout + result.stderr)
                self.assertFalse(self.log.exists())
                self.assertFalse((self.tmp / "home").exists())
