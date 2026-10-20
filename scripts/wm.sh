#!/bin/bash
# Shared entry point for skhd and SketchyBar; keep the AeroSpace CLI path intact.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/OmniWM.app/Contents/MacOS:$HOME/Applications/OmniWM.app/Contents/MacOS:$PATH"
config=${XDG_CONFIG_HOME:-$HOME/.config}
backend=$(cat "$config/wm/backend")
omniwmctl=${DOTFILES_OMNIWMCTL:-omniwmctl}
action=${1:-}
[[ $# == 0 ]] || shift
case "$backend" in aerospace|omniwm) ;; *) echo "Unknown backend: $backend" >&2; exit 2 ;; esac
if [[ "$action" == backend ]]; then echo "$backend"; exit; fi
if [[ "$action" == mode || "$action" == enter ]]; then
  logical_mode=${1:-main}
  callback_pid=${2:-$$}
  helper=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  # Stale callbacks must not overwrite a newer mode or run a delayed entry action.
  python3 "$helper/wm-mode.py" "$logical_mode" "$callback_pid" || exit $?
  if [[ "$action" == mode || $# -lt 3 ]]; then exit; fi
  shift 2
  action=$1
  shift
fi
if [[ "$action" == minimize ]]; then exec skhd -k 'cmd - m'; fi
if [[ "$action" == help ]]; then exec open "$config/$backend/help.html"; fi
if [[ "$backend" == aerospace ]]; then
  case "$action" in
    focus) exec aerospace focus --boundaries all-monitors-outer-frame "$@" ;;
    workspace) exec aerospace workspace "$@" ;;
    close) exec aerospace close ;;
    reload)
      helper=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
      lua "$helper/wm-config.lua" aerospace
      exec aerospace reload-config ;;
    *) echo "Unsupported AeroSpace action: $action" >&2; exit 2 ;;
  esac
fi
case "$action" in
  focus) exec "$omniwmctl" command focus "$@" ;;
  # 0.7.6 commits keyboard/CLI workspace switches immediately. Its animated
  # workspace preview is gesture-only; animationsEnabled does not alter this.
  workspace)
    # Paint the requested pill immediately; the native stream confirms it.
    sketchybar --trigger omniwm_event EVENT=workspace-requested WORKSPACE="$1" >/dev/null 2>&1 || true
    if "$omniwmctl" workspace focus-name "$@"; then exit 0; fi
    sketchybar --trigger omniwm_event EVENT=workspace-request-failed >/dev/null 2>&1
    exit 1 ;;
  close)
    helper=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    exec lua "$helper/wm-close.lua" ;;
  move) exec "$omniwmctl" command move "$@" ;;
  send) "$omniwmctl" command move-to-workspace "$@"; exec "$omniwmctl" workspace focus-name "$@" ;;
  resize)
    layout=$("$omniwmctl" query workspaces --current --fields layout --json |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["payload"]["workspaces"][0]["layout"])')
    if [[ "$layout" != niri ]]; then exec "$omniwmctl" command resize "$@"; fi
    orientation=$("$omniwmctl" query displays --current --fields orientation --json |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["payload"]["displays"][0]["orientation"])')
    case "$1:$orientation" in
      horizontal:horizontal|vertical:vertical) dimension=set-container-primary-span ;;
      *) dimension=set-window-secondary-span ;;
    esac
    if [[ "$2" == grow ]]; then delta=+25; else delta=-25; fi
    exec "$omniwmctl" command "$dimension" "$delta"
    ;;
  tile|floating|fullscreen|resize-step)
    helper=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    exec python3 "$helper/wm-window.py" "$action" "$@" ;;
  quake) exec "$omniwmctl" command toggle-quake-terminal ;;
  # Released 0.7.6: Dwindle <-> Niri is the complete workspace-layout cycle.
  # "default" inherits a layout; floating/fullscreen are window states.
  layout) exec "$omniwmctl" command toggle-workspace-layout ;;
  reload)
    helper=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    lua "$helper/wm-config.lua" omniwm
    exec skhd --reload ;; # OmniWM live-reloads its native settings.toml.
  pause) exec osascript -e 'tell application "OmniWM" to quit' ;;
  *) echo "Unsupported OmniWM action: $action" >&2; exit 2 ;;
esac
