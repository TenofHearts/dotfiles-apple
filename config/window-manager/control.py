#!/usr/bin/env python3
"""Shared WM shortcuts and a reversible AeroSpace/Rift selector."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

DIRECTORY = Path(__file__).resolve().parent
SETTING = DIRECTORY / 'manager'
os.environ['PATH'] = '/opt/homebrew/bin:/usr/local/bin:' + os.environ.get('PATH', '')


def run(*args, check=True):
    result = subprocess.run([str(arg) for arg in args], capture_output=True, text=True, timeout=15)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f'{args[0]} failed')
    return result


def query(*args):
    return json.loads(run('rift-cli', 'query', *args).stdout)


def execute(*args):
    return run('rift-cli', 'execute', *args)


def selected():
    value = SETTING.read_text().strip()
    if value not in ('aerospace', 'rift'):
        raise RuntimeError(f'Invalid window manager in {SETTING}: {value}')
    return value


def save_selection(value):
    temporary = SETTING.with_suffix('.tmp')
    temporary.write_text(value + '\n')
    temporary.replace(SETTING)


def wait_ready(manager):
    for _ in range(40):
        result = run(*(['rift-cli', 'query', 'displays'] if manager == 'rift' else
                       ['aerospace', 'list-workspaces', '--all', '--json']), check=False)
        if result.returncode == 0 and json.loads(result.stdout):
            return
        time.sleep(.25)
    raise RuntimeError(f'{manager} did not become ready. Check Accessibility permission and service logs.')


def start(manager):
    if manager == 'rift':
        # Uninstall on the AeroSpace path so Rift cannot restart beside it at login.
        if not (Path.home() / 'Library/LaunchAgents/git.acsandmann.rift.plist').exists():
            run('rift', 'service', 'install')
        run('rift', 'service', 'start')
    else:
        run('open', '-a', 'AeroSpace')
    wait_ready(manager)
    if manager == 'aerospace':
        run('aerospace', 'enable', 'on')
        run('aerospace', 'mode', 'main')


def stop_stream(manager):
    state = Path('/tmp') / f'sketchybar-{manager}-{os.getuid()}'
    try:
        pid = int((state / 'stream.pid').read_text())
    except (OSError, ValueError):
        return
    command = run('ps', '-p', pid, '-o', 'command=', check=False).stdout
    expected = str(DIRECTORY.parent / 'sketchybar/plugins' / f'{manager}-stream.lua')
    linked = str(Path.home() / '.config/sketchybar/plugins' / f'{manager}-stream.lua')
    if expected + ' listen' in command or linked + ' listen' in command:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def stop(manager):
    stop_stream(manager)
    if manager == 'rift':
        if (Path.home() / 'Library/LaunchAgents/git.acsandmann.rift.plist').exists():
            run('rift', 'service', 'stop')
            run('rift', 'service', 'uninstall')
    else:
        # Release parked windows before quitting.
        result = run('aerospace', 'enable', 'off', check=False)
        if result.returncode and 'running' not in result.stderr.lower():
            raise RuntimeError(result.stderr.strip())
        run('osascript', '-e', 'tell application "AeroSpace" to quit')


def switch(target):
    if target not in ('aerospace', 'rift'):
        raise RuntimeError('Use: switch aerospace|rift')
    if not shutil.which('rift' if target == 'rift' else 'aerospace'):
        raise RuntimeError(f'{target} is not installed')
    previous = selected()
    # Serialize switches without putting a lock in the tracked config directory.
    lock_path = Path.home() / '.local/state/dotfiles/window-manager.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = selected()
        try:
            stop('aerospace' if target == 'rift' else 'rift')
            start(target)
            save_selection(target)
            if target == 'rift':
                subscribe()
        except Exception:
            # Restore the prior manager and selector if startup failed.
            try:
                stop(target)
                start(previous)
                save_selection(previous)
            except Exception as rollback:
                print(f'Rollback needs attention: {rollback}', file=sys.stderr)
            raise
        run('skhd', '--reload', check=False)
        run('sketchybar', '--reload', check=False)
    print(f'Window manager: {target}')


def subscribe():
    run('lua', DIRECTORY.parent / 'sketchybar/plugins/rift-stream.lua', 'ensure')


def rift_action(action, args):
    if action == 'focus':
        execute('window', 'focus', args[0])
    elif action == 'workspace':
        execute('workspace', 'switch', int(args[0]) - 1)
    elif action == 'bar-workspace':
        execute('display', 'focus', '--uuid', args[0])
        execute('workspace', 'switch', args[1])
    elif action == 'close':
        execute('window', 'close')
    elif action == 'command':
        mode = query('binding-mode')
        execute('binding-mode', 'default' if mode == 'command' else 'command')
    elif action == 'join':
        run('lua', DIRECTORY.parent / 'rift/scripts/join.lua', args[0])
    elif action == 'help':
        execute('binding-mode', 'default')
        run('open', DIRECTORY.parent / 'rift/help.html')
    elif action == 'reload':
        execute('binding-mode', 'default')
        execute('config', 'reload')
    elif action == 'pause':
        execute('binding-mode', 'default')
        stop_stream('rift')
        run('rift', 'service', 'stop')
        run('sketchybar', '--set', 'rift.mode', 'label=PAUSED', check=False)
    elif action == 'resume':
        run('rift', 'service', 'start')
        wait_ready('rift')
        subscribe()
        run('sketchybar', '--reload', check=False)
    elif action == 'tile':
        workspaces = query('workspaces')
        focused = next((w for workspace in workspaces for w in workspace['windows'] if w['is_focused']), None)
        if focused and focused['is_floating']:
            execute('window', 'toggle-float')
    elif action == 'minimize':
        raise RuntimeError('Rift has no native minimize command; shortcut omitted in the Rift trial.')
    else:
        raise RuntimeError(f'Unknown Rift action: {action}')


def main():
    action, *args = sys.argv[1:]
    if action == 'switch':
        switch(args[0] if args else selected())
    elif action == 'status':
        print(selected())
    elif selected() == 'rift':
        rift_action(action, args)
    else:
        commands = {'focus': ['focus', '--boundaries', 'all-monitors-outer-frame', *args],
                    'workspace': ['workspace', *args], 'minimize': ['macos-native-minimize'],
                    'close': ['close'], 'resume': ['enable', 'on']}
        if action == 'command':
            mode = run('aerospace', 'list-modes', '--current').stdout.strip()
            commands[action] = ['mode', 'main' if mode == 'command' else 'command']
        if action not in commands:
            raise RuntimeError(f'Unknown AeroSpace action: {action}')
        run('aerospace', *commands[action])


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, IndexError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
