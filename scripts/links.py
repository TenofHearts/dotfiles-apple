#!/usr/bin/env python3
"""Backed-up, idempotent links; no third-party Python dependencies."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    ".config/aerospace/aerospace.toml": "config/aerospace/aerospace.toml",
    ".config/aerospace/help.html": "config/aerospace/help.html",
    ".zprofile": "config/zsh/.zprofile",
    ".zshrc": "config/zsh/.zshrc",
    ".config/oh-my-posh/theme.omp.json": "config/oh-my-posh/theme.omp.json",
    ".config/cowsay/stegosaurus_and_cat.cow": "config/cowsay/stegosaurus_and_cat.cow",
    "Library/Application Support/com.mitchellh.ghostty/config.ghostty": "config/ghostty/config.ghostty",
    ".gitconfig": "config/git/.gitconfig",
    ".gitignore_global": "config/git/.gitignore_global",
    ".Brewfile": "Brewfile",
    ".config/nvim": "config/nvim",
    ".config/karabiner": "config/karabiner",
    "Library/Keyboard Layouts/QWERTY no option.keylayout": "config/keyboard-layouts/QWERTY no option.keylayout",
}
for source in sorted((ROOT / "config/rime").glob("*.custom.yaml")):
    FILES[f"Library/Rime/{source.name}"] = str(source.relative_to(ROOT))


def exists(path):
    return os.path.lexists(path)


def linked(dest, source):
    return dest.is_symlink() and dest.resolve() == source.resolve()


def install(home, dry_run):
    pending = [(home / name, ROOT / src) for name, src in FILES.items()
               if not linked(home / name, ROOT / src)]
    # Never follow a parent directory link into an unrelated checkout.
    for dest, source in pending:
        if not source.exists():
            raise RuntimeError(f"Missing source: {source}")
        for parent in dest.parents:
            if parent == home:
                break
            if parent.is_symlink():
                raise RuntimeError(f"Symlinked parent needs manual review: {parent}")
    if not pending:
        print("All configuration links are already installed.")
        return
    for dest, source in pending:
        print(f"{'Back up and link' if exists(dest) else 'Link'} {dest} -> {source}")
    if dry_run:
        return
    backup = home / ".local/state/dotfiles/backups" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup.mkdir(parents=True, mode=0o700)
    manifest = backup / "manifest.json"
    records = []
    # Retain Karabiner assets and automatic backups through directory linking.
    old_karabiner = home / ".config/karabiner"
    if old_karabiner.is_dir() and not linked(old_karabiner, ROOT / "config/karabiner"):
        for name in ("assets", "automatic_backups"):
            source = old_karabiner / name
            dest = ROOT / "config/karabiner" / name
            if source.exists():
                if dest.exists():
                    raise RuntimeError(f"Refusing to merge Karabiner runtime data: {dest}")
                shutil.copytree(source, dest, symlinks=True)
    try:
        for dest, source in pending:
            saved = backup / dest.relative_to(home)
            record = {"dest": str(dest), "source": str(source),
                      "backup": str(saved) if exists(dest) else None}
            dest.parent.mkdir(parents=True, exist_ok=True)
            if exists(dest):
                saved.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(dest), str(saved))
            records.append(record)
            manifest.write_text(json.dumps(records, indent=2) + "\n")
            dest.symlink_to(os.path.relpath(source, dest.parent.resolve()), target_is_directory=source.is_dir())
    except Exception:
        for record in reversed(records):
            dest = Path(record["dest"])
            if linked(dest, Path(record["source"])):
                dest.unlink()
            if record["backup"] and exists(Path(record["backup"])) and not exists(dest):
                shutil.move(record["backup"], str(dest))
        raise
    print(f"Backup manifest: {manifest}")
    print("Restart Karabiner; use Squirrel > Deploy.")


def restore(manifest, dry_run):
    records = json.loads(manifest.read_text())
    # Check every entry before changing anything.
    for record in records:
        dest, source = Path(record["dest"]), Path(record["source"])
        if exists(dest) and not linked(dest, source):
            raise RuntimeError(f"Refusing to overwrite a changed file: {dest}")
        if record["backup"] and not exists(Path(record["backup"])):
            raise RuntimeError(f"Backup missing: {record['backup']}")
    for record in reversed(records):
        dest, source = Path(record["dest"]), Path(record["source"])
        print(f"Restore {dest}")
        if dry_run:
            continue
        if linked(dest, source):
            dest.unlink()
        if record["backup"]:
            shutil.move(record["backup"], str(dest))


def status(home):
    bad = False
    for name, source in FILES.items():
        ok = linked(home / name, ROOT / source)
        print(f"{'OK' if ok else 'MISSING/CHANGED'} {home / name}")
        bad |= not ok
    return int(bad)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "status", "restore"))
    parser.add_argument("manifest", nargs="?", type=Path)
    parser.add_argument("--home", type=Path, default=Path.home(), help="Alternate home for testing")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    home = args.home.absolute()
    if args.action == "install":
        install(home, args.dry_run)
    elif args.action == "status":
        return status(home)
    else:
        if not args.manifest:
            parser.error("restore requires a backup manifest")
        restore(args.manifest, args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        sys.exit(str(error))
