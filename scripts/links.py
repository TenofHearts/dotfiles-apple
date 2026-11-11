#!/usr/bin/env python3
"""Idempotent configuration links; no third-party Python dependencies."""
import argparse
import os
import shutil
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    ".config/skhd/skhdrc": "config/skhd/skhdrc",
    ".config/skhd/apps": "config/skhd/apps",
    ".config/skhd/wm": "config/aerospace/skhdrc",
    ".config/sketchybar": "config/sketchybar",
    ".config/aerospace/aerospace.toml": "config/aerospace/aerospace.toml",
    ".config/aerospace/help.html": "config/aerospace/help.html",
    ".config/omniwm/settings.toml": "config/omniwm/settings.toml",
    ".config/omniwm/help.html": "config/omniwm/help.html",
    ".config/wm/wm.sh": "scripts/wm.sh",
    ".config/wm/wm-mode.py": "scripts/wm-mode.py",
    ".config/wm/wm-window.py": "scripts/wm-window.py",
    ".config/wm/wm-config.lua": "scripts/wm-config.lua",
    ".config/wm/backend": "config/wm/aerospace",
    ".zprofile": "config/zsh/.zprofile",
    ".zshrc": "config/zsh/.zshrc",
    ".config/oh-my-posh/theme.omp.json": "config/oh-my-posh/theme.omp.json",
    ".config/cowsay/stegosaurus_and_cat.cow": "config/cowsay/stegosaurus_and_cat.cow",
    "Library/Application Support/com.mitchellh.ghostty/config.ghostty": "config/ghostty/config.ghostty",
    ".gitconfig": "config/git/.gitconfig",
    ".gitignore_global": "config/git/.gitignore_global",
    ".Brewfile": "Brewfile",
    ".config/nvim": "config/nvim",
    ".tmux.conf": "config/tmux/.tmux.conf",
    ".codex/dotfiles.config.toml": "config/ai/codex/dotfiles.config.toml",
    ".config/karabiner": "config/karabiner",
    "Library/Keyboard Layouts/QWERTY no option.keylayout": "config/keyboard-layouts/QWERTY no option.keylayout",
}
for source in sorted((ROOT / "config/rime").glob("*.custom.yaml")):
    FILES[f"Library/Rime/{source.name}"] = str(source.relative_to(ROOT))


def exists(path):
    return os.path.lexists(path)


def linked(dest, source):
    return dest.is_symlink() and dest.resolve() == source.resolve()


def app_for_source(source):
    if source == "Brewfile":
        return "homebrew"
    if source.startswith("scripts/"):
        return "wm"
    parts = source.split("/")
    return "codex" if parts[1] == "ai" else parts[1]


APPS = sorted({app_for_source(source) for source in FILES.values()})


def selected_files(only=None):
    if only is not None and only not in APPS:
        raise ValueError(f"Unknown app: {only}")
    return {name: source for name, source in FILES.items()
            if only is None or app_for_source(source) == only}


def install(home, dry_run, files=None, force=False):
    files = FILES if files is None else files
    skhd = home / ".config/skhd"
    migrate_skhd = force and skhd.is_symlink() and any(name.startswith(".config/skhd/") for name in files)
    if migrate_skhd and skhd.resolve() not in {
        ROOT / "config/skhd", ROOT / "config/aerospace", ROOT / "config/omniwm"
    }:
        raise RuntimeError(f"Symlinked parent needs manual review: {skhd}")
    pending = []
    for name, src in files.items():
        dest, source = home / name, ROOT / src
        migrating = migrate_skhd and name.startswith(".config/skhd/")
        # An existing skhd directory link owns all its children until forced migration.
        if skhd.is_symlink() and name.startswith(".config/skhd/") and not migrating:
            print(f"Skip existing parent link: {skhd}")
            continue
        if linked(dest, source) and not migrating:
            continue
        if exists(dest) and not migrating and not force:
            print(f"Skip existing configuration: {dest} (use --force to replace)")
            continue
        pending.append((dest, source))
    # Never follow a parent directory link into an unrelated checkout.
    for dest, source in pending:
        if not source.exists():
            shared = source.with_name(source.stem + ".shared.toml")
            if not (dry_run and source.suffix == ".toml" and shared.is_file()):
                raise RuntimeError(f"Missing source: {source}")
        for parent in dest.parents:
            if parent == home:
                break
            if parent.is_symlink() and not (migrate_skhd and parent == skhd):
                raise RuntimeError(f"Symlinked parent needs manual review: {parent}")
    if not pending:
        print("No configuration links to install.")
        return
    if migrate_skhd:
        print(f"Replace {skhd} with individual file links")
    for dest, source in pending:
        print(f"{'Replace and link' if exists(dest) else 'Link'} {dest} -> {source}")
    if dry_run:
        return
    # Retain Karabiner assets and automatic backups through directory linking.
    old_karabiner = home / ".config/karabiner"
    if (any(dest == old_karabiner for dest, _ in pending) and old_karabiner.is_dir()
            and not linked(old_karabiner, ROOT / "config/karabiner")):
        for name in ("assets", "automatic_backups"):
            source = old_karabiner / name
            dest = ROOT / "config/karabiner" / name
            if source.exists():
                if dest.exists():
                    raise RuntimeError(f"Refusing to merge Karabiner runtime data: {dest}")
                shutil.copytree(source, dest, symlinks=True)
    if migrate_skhd:
        skhd.unlink()
        skhd.mkdir()
    for dest, source in pending:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.is_symlink():
            dest.unlink()
        elif dest.is_dir():
            shutil.rmtree(dest)
        elif exists(dest):
            dest.unlink()
        dest.symlink_to(os.path.relpath(source, dest.parent.resolve()), target_is_directory=source.is_dir())
    if ".config/karabiner" in files:
        print("Restart Karabiner.")
    if any(name.startswith("Library/Rime/") for name in files):
        print("Use Squirrel > Deploy.")


def status(home, files=None):
    files = FILES if files is None else files
    bad = False
    for name, source in files.items():
        ok = linked(home / name, ROOT / source)
        print(f"{'OK' if ok else 'MISSING/CHANGED'} {home / name}")
        bad |= not ok
    return int(bad)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "status", "select-wm"))
    parser.add_argument("--wm", choices=("aerospace", "omniwm"), help="Window manager backend; defaults to the installed selection, then aerospace")
    parser.add_argument("--home", type=Path, default=Path.home(), help="Alternate home for testing")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true",
                        help="Delete conflicting configurations before installing links; no backups")
    parser.add_argument("--only", choices=APPS,
                        help="Install or inspect only the selected app configuration")
    args = parser.parse_args()
    if args.only and args.action not in ("install", "status"):
        parser.error("--only applies to install and status")
    if args.only and args.wm:
        parser.error("--only cannot be combined with --wm")
    if args.force and args.action != "install":
        parser.error("--force applies only to install")
    home = args.home.absolute()
    if args.only in (None, "skhd", "wm"):
        backend = args.wm
        selected = home / ".config/wm/backend"
        if backend is None:
            backend = selected.read_text().strip() if selected.is_file() else "aerospace"
        if backend not in ("aerospace", "omniwm"):
            parser.error(f"Unknown installed backend: {backend!r}")
        FILES[".config/wm/backend"] = f"config/wm/{backend}"
        FILES[".config/skhd/wm"] = f"config/{backend}/skhdrc"
    if args.action == "install":
        install(home, args.dry_run, selected_files(args.only), force=args.force)
    elif args.action == "select-wm":
        if not args.wm:
            parser.error("select-wm requires --wm aerospace|omniwm")
        install(home, args.dry_run, {name: FILES[name] for name in
                                  (".config/wm/backend", ".config/skhd/skhdrc",
                                   ".config/skhd/apps", ".config/skhd/wm")}, force=True)
    elif args.action == "status":
        return status(home, selected_files(args.only))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        sys.exit(str(error))
