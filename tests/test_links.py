import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
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

    def test_replacement_idempotence_and_rime_isolation(self):
        original = self.home / ".zprofile"
        original.symlink_to("old-profile")
        rime = self.home / "Library/Rime"
        rime.mkdir(parents=True)
        learned = rime / "user.yaml"
        learned.write_text("local data\n")
        links.install(self.home, False, force=True)
        self.assertEqual(links.status(self.home), 0)
        links.install(self.home, False)
        self.assertFalse((self.home / ".local/state/dotfiles").exists())
        self.assertEqual(learned.read_text(), "local data\n")
        self.assertFalse(rime.is_symlink())
        self.assertTrue(original.is_symlink())
        self.assertEqual(original.resolve(), links.ROOT / "config/zsh/.zprofile")

    def test_dry_run_has_no_writes(self):
        links.install(self.home, True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_codex_profile_replacement_preserves_local_state(self):
        codex = self.home / ".codex"
        codex.mkdir()
        profile = codex / "dotfiles.config.toml"
        profile.symlink_to("old-shared-profile")
        local = codex / "config.toml"
        local.write_text('[projects."/local/project"]\ntrust_level = "trusted"\n')
        auth = codex / "auth.json"
        auth.write_text("local auth placeholder\n")
        session = codex / "sessions" / "local-session.jsonl"
        session.parent.mkdir()
        session.write_text("local session placeholder\n")
        shell = self.home / ".zshrc"
        shell.write_text("keep local shell\n")
        files = links.selected_files("codex")
        links.install(self.home, True, files)
        self.assertFalse((self.home / ".local").exists())
        self.assertEqual(os.readlink(profile), "old-shared-profile")
        links.install(self.home, False, files, force=True)
        self.assertEqual(links.status(self.home, files), 0)
        self.assertTrue(profile.is_symlink())
        self.assertEqual(profile.resolve(), links.ROOT / "config/codex/dotfiles.config.toml")
        links.install(self.home, False, files)
        self.assertFalse((self.home / ".local").exists())
        self.assertTrue(profile.is_symlink())
        self.assertEqual(local.read_text(), '[projects."/local/project"]\ntrust_level = "trusted"\n')
        self.assertEqual(auth.read_text(), "local auth placeholder\n")
        self.assertEqual(session.read_text(), "local session placeholder\n")
        self.assertEqual(shell.read_text(), "keep local shell\n")
        self.assertFalse((self.home / ".config").exists())

    def test_codex_only_installer_initializes_only_its_submodule(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        log = self.home / "git-args"
        fake_git = bin_dir / "git"
        fake_git.write_text('#!/bin/sh\nprintf \'%s\\n\' "$@" > "$DOTFILES_TEST_GIT_LOG"\n')
        fake_git.chmod(0o755)
        # Make the installer check portable while preventing WM generation.
        for name, body in (("uname", "echo Darwin"), ("lua", "exit 99")):
            command = bin_dir / name
            command.write_text(f"#!/bin/sh\n{body}\n")
            command.chmod(0o755)
        env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
               "DOTFILES_TEST_GIT_LOG": str(log)}
        # Codex-only installation must not depend on the selected WM backend.
        backend = self.home / ".config/wm/backend"
        backend.parent.mkdir(parents=True)
        backend.write_text("unknown local backend\n")
        for option in (["--only", "codex"], ["--only=codex"], ["--only=codex", "--force"]):
            with self.subTest(option=option):
                if "--force" in option:
                    profile = self.home / ".codex/dotfiles.config.toml"
                    profile.unlink()
                    profile.symlink_to("missing-old-profile")
                result = subprocess.run(["bash", str(links.ROOT / "install.sh"), *option,
                                         "--home", str(self.home)], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(log.read_text().splitlines(),
                                 ["-C", str(links.ROOT), "submodule", "update", "--init",
                                  "--recursive", "--", "config/codex"])
        self.assertTrue((self.home / ".codex/dotfiles.config.toml").is_symlink())
        self.assertFalse((self.home / ".zshrc").exists())
        result = subprocess.run(["python3", str(links.ROOT / "scripts/links.py"), "status",
                                 "--only", "codex", "--home", str(self.home)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 1)

    def test_codex_installer_dry_run_and_invalid_selection_have_no_writes(self):
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        log = self.home / "commands"
        for name, body in (("uname", "echo Darwin"),
                           ("git", 'echo git >> "$DOTFILES_TEST_LOG"; exit 99'),
                           ("lua", 'echo lua >> "$DOTFILES_TEST_LOG"; exit 99')):
            command = bin_dir / name
            command.write_text(f"#!/bin/sh\n{body}\n")
            command.chmod(0o755)
        env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
               "DOTFILES_TEST_LOG": str(log)}
        target = self.home / "target"
        for options, expected in ((["--only", "codex", "--dry-run"], 0),
                                  (["--bootstrap", "--only=codex", "--dry-run"], 0),
                                  (["--only="], 2), (["--only", "unknown"], 2), (["--only"], 2)):
            with self.subTest(options=options):
                result = subprocess.run(["bash", str(links.ROOT / "install.sh"),
                                         *options,
                                         "--home", str(target)], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertFalse(target.exists())
                self.assertFalse(log.exists())

    def test_missing_source_is_rejected_before_replacing_files(self):
        original = self.home / ".zshrc"
        original.write_text("keep this file\n")
        with self.assertRaises(RuntimeError):
            links.install(self.home, False, {
                ".zshrc": "config/zsh/.zshrc",
                ".missing": "config/missing/source",
            })
        self.assertEqual(original.read_text(), "keep this file\n")
        self.assertFalse((self.home / ".local").exists())

    def test_symlink_parent_rejected(self):
        target = self.home / "elsewhere"
        target.mkdir()
        (self.home / "Library").symlink_to(target)
        with self.assertRaises(RuntimeError):
            links.install(self.home, False)
        self.assertFalse((self.home / ".zprofile").exists())

    def test_dangling_link_requires_force(self):
        dest = self.home / ".zshrc"
        dest.symlink_to("missing-original")
        links.install(self.home, False)
        self.assertEqual(os.readlink(dest), "missing-original")
        links.install(self.home, True, force=True)
        self.assertEqual(os.readlink(dest), "missing-original")
        links.install(self.home, False, force=True)
        self.assertTrue(dest.is_symlink())
        self.assertEqual(dest.resolve(), links.ROOT / "config/zsh/.zshrc")
        self.assertFalse((self.home / ".local").exists())

    def test_conflicting_directory_requires_force(self):
        dest = self.home / ".config/nvim"
        dest.mkdir(parents=True)
        (dest / "local-config").write_text("old config\n")
        external = self.home / "external"
        external.mkdir()
        retained = external / "keep"
        retained.write_text("external data\n")
        (dest / "external-link").symlink_to(external, target_is_directory=True)
        links.install(self.home, False)
        self.assertFalse(dest.is_symlink())
        self.assertEqual((dest / "local-config").read_text(), "old config\n")
        links.install(self.home, False, force=True)
        self.assertTrue(dest.is_symlink())
        self.assertEqual(dest.resolve(), links.ROOT / "config/nvim")
        self.assertEqual(retained.read_text(), "external data\n")
        self.assertFalse((self.home / ".local").exists())

    def test_skhd_backend_selection_keeps_the_shared_entry_point(self):
        links.install(self.home, False)
        skhd = self.home / ".config/skhd"
        self.assertFalse(skhd.is_symlink())
        shared = (skhd / "skhdrc").resolve()
        files = {".config/skhd/wm": "config/omniwm/skhdrc",
                 ".config/wm/backend": "config/wm/omniwm"}
        links.install(self.home, False, files, force=True)
        self.assertEqual((skhd / "skhdrc").resolve(), shared)
        self.assertEqual((skhd / "wm").resolve(), links.ROOT / "config/omniwm/skhdrc")
        self.assertEqual((skhd / "apps").resolve(), links.ROOT / "config/skhd/apps")

    def test_old_skhd_directory_links_migrate_without_changing_sources(self):
        for backend in ("skhd", "omniwm"):
            with self.subTest(backend=backend):
                home = self.home / backend
                config = home / ".config"
                config.mkdir(parents=True)
                original = links.ROOT / "config" / backend
                (config / "skhd").symlink_to(original, target_is_directory=True)
                links.install(home, False)
                self.assertTrue((config / "skhd").is_symlink())
                links.install(home, False, force=True)
                self.assertFalse((config / "skhd").is_symlink())
                self.assertTrue((config / "skhd/skhdrc").is_file())
                self.assertEqual(links.status(home), 0)
                links.install(home, False)
                self.assertFalse((home / ".local").exists())
                self.assertFalse((config / "skhd").is_symlink())
                self.assertTrue(original.is_dir())
                self.assertFalse(original.is_symlink())

    def test_reinstall_preserves_unmanaged_skhd_files(self):
        skhd = self.home / ".config/skhd"
        skhd.parent.mkdir()
        skhd.symlink_to(links.ROOT / "config/omniwm", target_is_directory=True)
        links.install(self.home, False, force=True)
        local = skhd / "local-shortcuts"
        local.write_text("keep this file\n")
        links.install(self.home, False)
        self.assertEqual(local.read_text(), "keep this file\n")
        self.assertTrue((skhd / "skhdrc").is_file())
        self.assertFalse((self.home / ".local").exists())

    def test_existing_file_and_wrong_target_link_are_preserved(self):
        original = self.home / ".zprofile"
        original.write_text("local settings\n")
        dest = self.home / ".zshrc"
        dest.symlink_to(original)
        files = {".zprofile": "config/zsh/.zprofile", ".zshrc": "config/zsh/.zshrc"}
        links.install(self.home, False, files)
        self.assertEqual(dest.resolve(), original.resolve())
        links.install(self.home, False, files, force=True)
        self.assertTrue(original.is_symlink())
        self.assertEqual(original.resolve(), links.ROOT / "config/zsh/.zprofile")
        self.assertEqual(dest.resolve(), links.ROOT / "config/zsh/.zshrc")
