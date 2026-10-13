#!/usr/bin/env python3
"""Read system state; send one batched update to SketchyBar."""
import json
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, timeout=8, stderr=subprocess.DEVNULL)


def bluetooth():
    data = json.loads(run('system_profiler', 'SPBluetoothDataType', '-json'))['SPBluetoothDataType']
    controller = data[0] if data else {}
    state = controller.get('controller_properties', {}).get('controller_state')
    count = sum(len(group) for group in controller.get('device_connected', []))
    label = (str(count) + ' connected' if count else 'On') if state == 'attrib_on' else 'Off'
    if state not in ('attrib_on', 'attrib_off'):
        label = 'Unknown'
    run('sketchybar', '--set', 'bluetooth', 'label=' + label,
        'icon.color=' + ('0xff89b4fa' if state == 'attrib_on' else '0xff9399b2'))


def network():
    # Reachability describes a usable network route, not a successful Internet probe.
    state = run('/usr/sbin/scutil', '--nwi')
    connected = '(Reachable)' in state
    run('sketchybar', '--set', 'network',
        'icon=' + ('󰖩' if connected else '󰖪'),
        'label=' + ('Connected' if connected else 'Offline'),
        'icon.color=' + ('0xffa6e3a1' if connected else '0xff9399b2'))


if __name__ == '__main__':
    name = sys.argv[1]
    try:
        {'bluetooth': bluetooth, 'network': network}[name]()
    except (subprocess.SubprocessError, OSError, ValueError, KeyError) as error:
        # Avoid retaining a misleading successful status if a provider stops responding.
        args = ['sketchybar', '--set', name, 'label=Unavailable']
        subprocess.run(args, timeout=5, check=False)
        print(f'{name}: {error}', file=sys.stderr)
        sys.exit(1)
