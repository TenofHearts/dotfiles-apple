#!/usr/bin/env python3
"""Install a pinned Rime Ice baseline, preserving all existing user data."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REVISION = "3aea6d3694fb3d94ec663641f021f788822897ad"
target = Path.home() / "Library/Rime"
if (target / "rime_ice.schema.yaml").exists():
    print("Rime Ice already exists; leaving it unchanged.")
else:
    with tempfile.TemporaryDirectory(prefix="dotfiles-rime-") as tmp:
        repo = Path(tmp) / "rime-ice"
        subprocess.run(["git", "clone", "--no-checkout", "https://github.com/iDvel/rime-ice.git", str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "checkout", "--detach", REVISION], check=True)
        for source in repo.rglob("*"):
            rel = source.relative_to(repo)
            if any(part.startswith(".") for part in rel.parts) or source.name.endswith(".custom.yaml"):
                continue
            dest = target / rel
            if source.is_file() and not os.path.lexists(dest):
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, dest)
    print("Installed Rime Ice baseline. Install links, then use Squirrel > Deploy.")
