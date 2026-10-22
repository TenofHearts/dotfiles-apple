# SketchyBar

The Lua configuration uses the backend selected in `~/.config/wm/backend`. Run `scripts/lua-setup.sh` to install its pinned Lua 5.5 modules, then `sketchybar --reload` to load configuration changes.

After wake, the bar waits for three seconds without display-change notifications before rebuilding its native windows. OmniWM workspace updates also wait for displays to settle and request fresh event snapshots. Cached focus events cannot override workspace highlights, and failed display queries preserve the last valid pills while retrying.

See [tests](../../tests/README.md) for automated checks. A real sleep/wake cycle is still needed to verify macOS window rendering and display reconnection.
