#!/usr/bin/env python3
"""Publish skhd mode callbacks in event order, even when children run late."""

import ctypes
import fcntl
import json
import os
from pathlib import Path
import struct
import subprocess
import sys


def process_order(pid):
    # Darwin PROC_PIDTBSDINFO: the final fields are the kernel fork timestamp.
    # Use the shell forked by skhd, not the eventual callback execution time.
    info = ctypes.create_string_buffer(136)
    libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    if libproc.proc_pidinfo(pid, 3, 0, info, len(info)) != len(info):
        raise OSError(ctypes.get_errno(), "Cannot read mode callback process")
    return struct.unpack_from("QQ", info.raw, 120)


def publish(directory, mode, order):
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "wm-mode.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        version = directory / "wm-mode-order"
        previous = json.loads(version.read_text()) if version.exists() else [0, 0]
        if tuple(order) < tuple(previous):
            return False
        temporary = directory / "wm-mode.tmp"
        temporary.write_text(mode + "\n")
        temporary.replace(directory / "wm-mode")
        version.write_text(json.dumps(order))
    return True


def main():
    directory = (
        Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
        / "dotfiles"
    )
    if not publish(directory, sys.argv[1], process_order(int(sys.argv[2]))):
        return 3
    try:
        subprocess.run(
            [
                os.environ.get("DOTFILES_SKETCHYBAR", "sketchybar"),
                "--trigger",
                "omniwm_event",
                "EVENT=mode-changed",
            ],
            check=False,
            timeout=2,
            stdout=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
