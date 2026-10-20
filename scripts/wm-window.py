#!/usr/bin/env python3
"""Serialize OmniWM window state changes and bounded Niri resize steps."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib


RESIZE_PERCENTAGES = (25, 33, 50, 100)


def run(*args):
    return subprocess.run([os.environ.get('DOTFILES_OMNIWMCTL', 'omniwmctl'), *args],
                          check=True, capture_output=True, text=True, timeout=5).stdout


def focused():
    rows = json.loads(run('query', 'windows', '--focused', '--json'))['result']['payload']['windows']
    return rows[0] if rows else None


def next_percentage(current, direction, tolerance=0.5):
    # Accept pixel rounding and existing one-third sizes as the 33% step.
    if direction == 'grow':
        return next((p for p in RESIZE_PERCENTAGES if p > current + tolerance), None)
    return next((p for p in reversed(RESIZE_PERCENTAGES) if p < current - tolerance), None)


def resize_step(axis, direction):
    if axis not in ('horizontal', 'vertical') or direction not in ('grow', 'shrink'):
        raise ValueError('Expected horizontal|vertical and grow|shrink')
    window = focused()
    if window is None or window['mode'] != 'tiling' or window['isFullscreen']:
        return
    workspace = json.loads(run('query', 'workspaces', '--workspace', window['workspace']['id'],
                               '--json'))['result']['payload']['workspaces'][0]
    if workspace['layout'] != 'niri':
        return
    display = json.loads(run('query', 'displays', '--display', window['display']['id'],
                             '--json'))['result']['payload']['displays'][0]
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
    settings_path = config / 'omniwm/settings.toml'
    settings = tomllib.loads(settings_path.read_text()) if settings_path.exists() else {}
    gap = display['innerGap']
    visible = display['visibleFrame']
    if axis == 'horizontal':
        dimension = 'width'
        available = visible['width'] - display['outerGapLeft'] - display['outerGapRight']
    else:
        dimension = 'height'
        frame = display['frame']
        menu_inset = max(0, frame['y'] + frame['height'] - visible['y'] - visible['height'])
        available = visible['height'] - max(0, display['outerGapTop'] - menu_inset) - display['outerGapBottom']
    if not settings.get('niri', {}).get('edgeGaps', True):
        available += 2 * gap
    # OmniWM resolves p% as (working span - inner gap) * p / 100 - inner gap.
    proportional_span = available - gap
    if proportional_span <= 0:
        return
    current = 100 * (window['frame'][dimension] + gap) / proportional_span
    target = next_percentage(current, direction, max(0.5, 100 / proportional_span))
    if target is None:
        return
    command = ('set-container-primary-span' if axis == display['orientation']
               else 'set-window-secondary-span')
    latest = focused()
    if latest is None or latest['id'] != window['id']:
        raise RuntimeError('Focus changed while resizing; stopped')
    run('command', command, f'{target}%')


def change(action):
    if action == 'resize-step':
        resize_step(*sys.argv[2:])
        return
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
    except (OSError, ValueError, KeyError, IndexError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'OmniWM {sys.argv[1]}: {error}', file=sys.stderr)
        sys.exit(1)
