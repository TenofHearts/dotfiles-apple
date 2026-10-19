#!/bin/bash
# Manage skhd independently of window managers and bootstrap.
set -euo pipefail
action=${1:-}
case "$action" in
  start|stop|restart) ;;
  *) echo "Usage: $0 start|stop|restart" >&2; exit 2 ;;
esac
if [[ $# != 1 ]]; then
  echo "Usage: $0 start|stop|restart" >&2
  exit 2
fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v skhd >/dev/null 2>&1; then
  echo 'Install skhd first: brew install asmvik/formulae/skhd' >&2
  exit 1
fi
if [[ "$action" != stop && ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/skhd/skhdrc" ]]; then
  echo 'Link the configuration first: ./install.sh' >&2
  exit 1
fi
if [[ "$action" != stop && -x "${XDG_CONFIG_HOME:-$HOME/.config}/wm/wm.sh" ]]; then
  "${XDG_CONFIG_HOME:-$HOME/.config}/wm/wm.sh" mode main
fi
exec skhd "--${action}-service"
