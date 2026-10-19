#!/bin/bash
# Explicit lifecycle, following skhd-service.sh: installation starts no services.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/OmniWM.app/Contents/MacOS:$HOME/Applications/OmniWM.app/Contents/MacOS:$PATH"
config=${XDG_CONFIG_HOME:-$HOME/.config}
action=${1:-}
case "$action" in
  start|stop|restart) [[ $# == 1 ]] || exit 2 ;;
  switch) [[ $# == 2 && ( "$2" == aerospace || "$2" == omniwm ) ]] || exit 2 ;;
  *) echo "Usage: $0 start|stop|restart|switch aerospace|omniwm" >&2; exit 2 ;;
esac
backend=$(cat "$config/wm/backend")
case "$backend" in aerospace|omniwm) ;; *) echo "Unknown backend: $backend" >&2; exit 2 ;; esac
app_name() { if [[ "$1" == aerospace ]]; then echo AeroSpace; else echo OmniWM; fi; }
stop() {
  local app
  app=$(app_name "$1")
  # Do not launch an app just to quit it.
  if pgrep -x "$app" >/dev/null; then
    osascript -e "tell application \"$app\" to quit" || return
    for ((i=0; i<50; i++)); do
      if ! pgrep -x "$app" >/dev/null; then return; fi
      sleep 0.1
    done
    echo "$app did not quit; refusing to start a competing manager." >&2
    return 1
  fi
}
check() {
  local app
  app=$(app_name "$1")
  if [[ ! -d "/Applications/$app.app" && ! -d "$HOME/Applications/$app.app" ]]; then
    echo "Install $app first with Homebrew or in /Applications." >&2; return 1
  fi
  [[ -f "$config/$1/$(if [[ "$1" == aerospace ]]; then echo aerospace.toml; else echo settings.toml; fi)" ]] || {
    echo 'Link the configuration first: ./install.sh' >&2; return 1;
  }
}
start() {
  check "$1" || return
  local other=aerospace
  [[ "$1" != aerospace ]] || other=omniwm
  stop "$other" || return
  open -a "$(app_name "$1")"
}
refresh() {
  "$config/wm/wm.sh" mode main
  if pgrep -x skhd >/dev/null; then skhd --reload; fi
  if pgrep -x sketchybar >/dev/null; then sketchybar --reload; fi
}
case "$action" in
  start) start "$backend" ;;
  stop) stop "$backend" ;;
  restart) check "$backend"; stop "$backend"; start "$backend" ;;
  switch)
    target=$2
    check "$target"
    # Backend links use the same backup/restore machinery as installation.
    stop "$backend"
    if ! python3 "$ROOT/scripts/links.py" select-wm --wm "$target" || ! start "$target"; then
      stop "$target"
      python3 "$ROOT/scripts/links.py" select-wm --wm "$backend"
      start "$backend"
      refresh
      exit 1
    fi
    if [[ "$backend" != "$target" ]]; then
      pid_file="/tmp/sketchybar-$backend-$(id -u)/stream.pid"
      if [[ -f "$pid_file" ]]; then
        pid=$(cat "$pid_file")
        if [[ "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" -o command= | /usr/bin/grep -Fq "/plugins/$backend-stream.lua"; then
          kill -TERM "$pid" || true
        fi
      fi
    fi
    refresh
    echo "Selected $target. Complete its macOS permissions if prompted."
    ;;
esac
