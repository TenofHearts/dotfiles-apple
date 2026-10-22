# Tests

Run from the repository root:

```sh
python3 -m unittest discover -s tests
lua tests/test_sketchybar.lua
```

The Python tests check link installation and restoration in temporary home directories. The Lua tests simulate SketchyBar events and asynchronous queries, using the real OmniWM workspace conversion to check wake settling, stale focus, display-cache invalidation, retry recovery, and item ordering. They use stock Lua and do not contact running applications or put the Mac to sleep.

For syntax and whitespace checks:

```sh
bash -n scripts/wm.sh
find config/sketchybar tests -name '*.lua' -exec luac -p {} +
git diff --check
```
