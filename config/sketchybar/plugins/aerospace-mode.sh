#!/bin/bash
# Read current state so delayed callbacks do not replay an obsolete mode.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! mode=$(aerospace list-modes --current); then
  exec sketchybar --set aerospace.mode label=Unavailable label.color=0xfffab387
fi
color=0xfffab387
[[ "$mode" == main ]] && color=0xffffffff
label=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
exec sketchybar --set aerospace.mode "label=$label" "label.color=$color"
