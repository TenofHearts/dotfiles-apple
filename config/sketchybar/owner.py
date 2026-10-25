#!/usr/bin/env python3
"""Replace this bar's Lua configuration before exec, without an idle supervisor."""
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def configurations(parent, entry, pids=None):
    if pids is not None and not pids:
        return {}
    entry = entry.resolve()
    fields = 'uid=,pid=,ppid=,lstart=,command='
    arguments = (['-axo', fields] if pids is None else
                 ['-p', ','.join(map(str, pids)), '-o', fields])
    try:
        output = subprocess.check_output(['/bin/ps', *arguments], text=True)
    except subprocess.CalledProcessError as error:
        if pids is not None and error.returncode == 1 and not error.output:
            return {}
        raise
    result = {}
    for line in output.splitlines():
        fields = line.split(None, 8)
        if len(fields) != 9:
            continue
        uid, pid, ppid = map(int, fields[:3])
        command = fields[8]
        executable, _, script = command.partition(' ')
        if (uid == os.getuid() and ppid == parent and Path(executable).name == 'lua'
                and Path(script).resolve() == entry):
            result[pid] = tuple(fields[3:])
    return result


def main():
    entry = Path(sys.argv[1]).resolve(strict=True)
    parent = os.getppid()
    bar = os.environ.get('BAR_NAME', 'sketchybar').encode().hex()
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    state = state / 'dotfiles/sketchybar' / bar
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Never unlink this lock: another launcher may already have it open.
    with (state / 'replace.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = configurations(parent, entry)
        for pid, identity in previous.items():
            if configurations(parent, entry, [pid]).get(pid) == identity:
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
        deadline = time.monotonic() + 3
        while previous:
            current = configurations(parent, entry, previous)
            previous = {pid: identity for pid, identity in previous.items()
                        if current.get(pid) == identity}
            if not previous:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Previous SketchyBar configuration did not exit')
            time.sleep(0.02)
        os.environ['DOTFILES_SBAR_DAEMON_PID'] = str(parent)
        # Python's lock descriptor closes at exec. Concurrent reloads serialize
        # replacement, and the final launcher becomes the sole configuration.
        os.execvp('lua', ['lua', str(entry)])


if __name__ == '__main__':
    main()
