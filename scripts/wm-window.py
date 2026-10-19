#!/usr/bin/env python3
"""Serialize state changes and implement set-tiled using OmniWM's toggle API."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.run([os.environ.get('DOTFILES_OMNIWMCTL', 'omniwmctl'), *args],
                          check=True, capture_output=True, text=True, timeout=5).stdout


def focused():
    rows = json.loads(run('query', 'windows', '--focused', '--json'))['result']['payload']['windows']
    return rows[0] if rows else None


def change(action):
    window = focused()
    if window is None:
        # A browser may replace its native window before the discovery callback.
        # Native rule application can admit that frontmost window without a restart.
        run('rule', 'apply', '--focused')
        window = focused()
    if window is None:
        raise RuntimeError('OmniWM has no managed focused window')
    target = window['id']
    if action != 'tile':
        run('command', 'toggle-fullscreen' if action == 'fullscreen' else 'toggle-focused-window-floating')
        return
    # A manual force-float override on an automatically floating window takes
    # TWO toggles: clear override, then force-tile. Never toggle an existing tile.
    for attempt in range(3):
        window = focused()
        if window is None or window['id'] != target:
            raise RuntimeError('Focus changed while setting tiled; stopped')
        if window['mode'] == 'tiling':
            return
        if attempt < 2:
            run('command', 'toggle-focused-window-floating')
    raise RuntimeError('OmniWM kept the focused window floating after two toggles')


def main():
    directory = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'dotfiles'
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'wm-window.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        change(sys.argv[1])


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'OmniWM {sys.argv[1]}: {error}', file=sys.stderr)
        sys.exit(1)
