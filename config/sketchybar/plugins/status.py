#!/usr/bin/env python3
"""Read system state; send one batched update to SketchyBar."""
import json
import shlex
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, timeout=8, stderr=subprocess.DEVNULL)


def aerospace():
    rows = json.loads(run('aerospace', 'list-workspaces', '--all', '--format',
                          '%{workspace} %{monitor-appkit-nsscreen-screens-id}', '--json'))
    occupied = set(run('aerospace', 'list-workspaces', '--monitor', 'all', '--empty', 'no').splitlines())
    visible = set(run('aerospace', 'list-workspaces', '--monitor', 'all', '--visible').splitlines())
    existing = set(json.loads(run('sketchybar', '--query', 'bar'))['items'])
    desired = set()
    args = ['sketchybar']
    for row in rows:
        workspace = row['workspace']
        # Encoding keeps arbitrary workspace names safe as item identifiers.
        name = 'aerospace.workspace.' + workspace.encode().hex()
        desired.add(name)
        if name not in existing:
            args += ['--add', 'item', name, 'left', '--move', name, 'before', 'aerospace.mode']
        active = workspace in visible
        args += ['--set', name, 'icon=' + workspace,
                 'icon.font=SF Pro:Semibold:12.0', 'icon.width=20',
                 'icon.align=center', 'icon.padding_left=5', 'icon.padding_right=5',
                 'icon.color=' + ('0xff1e1e2e' if active else '0xffcdd6f4'),
                 'label=●', 'label.drawing=' + ('on' if active else 'off'),
                 'label.font=SF Pro:Regular:8.0', 'label.color=0xff1e1e2e',
                 'label.padding_left=0', 'label.padding_right=7',
                 'padding_left=3', 'padding_right=3',
                 'display=' + str(row['monitor-appkit-nsscreen-screens-id']),
                 'drawing=' + ('on' if workspace in occupied or active else 'off'),
                 'background.drawing=on', 'background.height=22',
                 'background.color=' + ('0xff89b4fa' if active else '0x30313244'),
                 'background.corner_radius=11',
                 'click_script=aerospace workspace -- ' + shlex.quote(workspace)]
    for stale in sorted(existing - desired):
        if stale.startswith('aerospace.workspace.'):
            args += ['--remove', stale]
    run(*args)


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
        {'aerospace': aerospace, 'bluetooth': bluetooth, 'network': network}[name]()
    except (subprocess.SubprocessError, OSError, ValueError, KeyError) as error:
        # Avoid retaining a misleading successful status if a provider stops responding.
        item = 'aerospace.refresh' if name == 'aerospace' else name
        args = ['sketchybar', '--set', item, 'label=Unavailable']
        if name == 'aerospace':
            args += ['--set', '/aerospace.workspace.*/', 'drawing=off']
        subprocess.run(args, timeout=5, check=False)
        print(f'{name}: {error}', file=sys.stderr)
