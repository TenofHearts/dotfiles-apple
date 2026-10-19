#!/bin/sh
# With no argument, apply config/window-manager/manager. With an argument, switch and save it.
set -eu
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$root/config/window-manager/control.py" switch "$@"
