#!/bin/sh
# Fast path for skhd: no interpreter startup or bar queries before a WM command.
set -eu
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
IFS= read -r manager < "$HOME/.config/window-manager/manager"
action=$1
shift
case "$manager:$action" in
  rift:workspace) exec rift-cli execute workspace switch "$(($1 - 1))" ;;
  rift:focus) exec rift-cli execute window focus "$1" ;;
  rift:close) exec rift-cli execute window close ;;
  rift:minimize) exit 0 ;;
  rift:command)
    mode=$(rift-cli query binding-mode)
    case "$mode" in '"command"') mode=default ;; *) mode=command ;; esac
    exec rift-cli execute binding-mode "$mode" ;;
  aerospace:workspace) exec aerospace workspace "$1" ;;
  aerospace:focus) exec aerospace focus --boundaries all-monitors-outer-frame "$1" ;;
  aerospace:close) exec aerospace close ;;
  aerospace:minimize) exec aerospace macos-native-minimize ;;
  aerospace:command)
    mode=$(aerospace list-modes --current)
    case "$mode" in command) mode=main ;; *) mode=command ;; esac
    exec aerospace mode "$mode" ;;
  *) echo "Unknown manager/action: $manager:$action" >&2; exit 1 ;;
esac
