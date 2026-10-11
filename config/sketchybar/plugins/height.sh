#!/bin/bash
# Ask AppKit instead of guessing a height from the screen resolution.
height=$(/usr/bin/osascript -l JavaScript -e \
  'ObjC.import("AppKit"); $.NSApplication.sharedApplication; $.NSMenu.menuBarHeight')
if [[ "$height" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  sketchybar --bar height="${height%.*}" notch_display_height="${height%.*}"
fi
