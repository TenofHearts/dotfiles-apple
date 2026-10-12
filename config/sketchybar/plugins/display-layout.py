#!/usr/bin/env python3
"""Measure native menus and synchronize SketchyBar heights and AeroSpace gaps."""
import fcntl
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

PLUGIN_DIR = Path(__file__).resolve().parent
MARKER = '# managed by sketchybar display-layout.py'


def run(*args):
    return subprocess.check_output(args, text=True, timeout=10)


def plan(screens, monitors):
    if not screens or any(s['height'] is None for s in screens):
        raise ValueError('Native menu dimensions are not available for every display')
    heights = {kind: min(s['height'] for s in screens if s['notch'] == kind)
               for kind in {s['notch'] for s in screens}}
    props = [('notch_display_height' if kind else 'height') + '=' + str(math.floor(h))
             for kind, h in sorted(heights.items())]
    ids = {m['monitor-appkit-nsscreen-screens-id']: m['monitor-id'] for m in monitors}
    if set(ids) != {s['screen'] for s in screens}:
        raise ValueError('Display topology is still changing')
    gaps = [(ids[s['screen']], math.ceil(max(0, math.floor(heights[s['notch']]) - s['inset']) + 5))
            for s in screens]
    rules = [f'{{ monitor."{monitor}" = {gap} }}' for monitor, gap in sorted(gaps)]
    rules.append(str(math.ceil(max(heights.values()) + 5)))
    return props, 'outer.top = [' + ', '.join(rules) + '] ' + MARKER


def sync():
    screens = json.loads(run('osascript', '-l', 'JavaScript', str(PLUGIN_DIR / 'display-metrics.js')))
    monitors = json.loads(run('aerospace', 'list-monitors', '--format',
                             '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}', '--json'))
    props, gap_line = plan(screens, monitors)
    # Follow the active config symlink instead of replacing it.
    config = Path(run('aerospace', 'config', '--config-path').strip()).resolve()
    original = config.read_text()
    updated, count = re.subn(r'^outer\.top = .*' + re.escape(MARKER) + r'$',
                             lambda _: gap_line, original, flags=re.MULTILINE)
    if count != 1:
        raise ValueError('Expected one managed outer.top line in AeroSpace config')
    run('sketchybar', '--bar', *props)
    if updated != original:
        with tempfile.NamedTemporaryFile(mode='w', dir=config.parent, delete=False) as file:
            temporary = Path(file.name)
            file.write(updated)
        temporary.chmod(config.stat().st_mode & 0o777)
        temporary.replace(config)
        try:
            run('aerospace', 'reload-config')
        except (OSError, subprocess.SubprocessError):
            config.write_text(original)
            run('aerospace', 'reload-config')
            raise
    print(json.dumps({'screens': screens, 'bar': props, 'gaps': gap_line}))


def main():
    # Serialize display-change, startup and wake updates.
    with (PLUGIN_DIR / '.display-layout.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        for attempt in range(3):
            try:
                sync()
                return
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                if attempt == 2:
                    print(f'display-layout: {error}', file=sys.stderr)
                    sys.exit(1)
                time.sleep(1)


if __name__ == '__main__':
    main()
