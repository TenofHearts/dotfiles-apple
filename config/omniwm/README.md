# OmniWM backend

Targets [OmniWM 0.7.6](https://github.com/OmniNull/OmniWM/releases/tag/v0.7.6), schema 4. Use the released source when checking compatibility; the website also documents unreleased features. OmniWM requires Apple Silicon and macOS 26+.

## Setup and switching

Install with `./install.sh --wm omniwm`, open OmniWM to grant Accessibility and Input Monitoring, and enable **Displays have separate Spaces** in macOS settings. Start skhd separately with `./scripts/skhd-service.sh start`. Keep Start at Login disabled in both window manager apps.

For an installed desktop, use `./scripts/wm-service.sh switch omniwm` or `switch aerospace`. `start`, `stop`, and `restart` operate on the selected backend. Selecting links alone does not switch running apps. Switching preserves the configs, but runtime workspace membership, focus history, fullscreen state, and container trees belong to each manager.

The [hotkey guide](help.html) lists active bindings. Left Option refers to the modifier after Karabiner remapping; release modifiers before using plain mode keys. Left Option + Escape resets OmniWM bindings to Main, including while Shift is held.

## Differences from AeroSpace

| Operation | OmniWM behavior |
| --- | --- |
| Option + H/J/K/L, 1–9, M, Q | Directional focus across monitor edges, workspace selection, minimize, and close. Shared across modes. |
| Command → Move / Adjust / Admin | Implemented with skhd capture modes. There is no separate Join mode. |
| Move H/J/K/L | Dwindle joins a singleton to a touching tile or extracts an active tab. Groups are tabbed; arbitrary AeroSpace container trees cannot be reproduced. |
| Move Shift + H/J/K/L | Swaps the two displays' active workspaces. The destination workspace moves back to the source display. |
| Move 1–9 | Moves the focused window and follows it; stays in Move. |
| Adjust H/J/K/L | Dwindle uses native 10% split-ratio steps; Niri uses physical 25-point size changes. |
| Adjust Space | Cycles the current workspace through Dwindle → Niri → Dwindle; stays in Adjust. Switching rebuilds its arrangement. |
| Adjust A | Unbound: OmniWM has no accordion layout. |
| Adjust T / W / F | Set tiled / toggle floating / toggle fullscreen. F again restores the previous state; T does not exit fullscreen. |
| Admin R | Returns to Main and reloads skhd. OmniWM settings reload automatically when saved. |
| Admin P | Returns to Main and quits OmniWM. Relaunch it or use `wm-service.sh start` to resume; there is no stable CLI pause/resume command. |
| Mouse centering on monitor change | Supplied by the SketchyBar event stream; SketchyBar must be running. |

There are nine persistent workspace definitions, initially assigned to the main display. Window rules float WeChat calls and browser picture-in-picture windows. Inner gaps are 2 points and outer left/right/bottom gaps are 5 points. SketchyBar measures the top gap to leave 5 points below the bar. A large custom single-window fit fills the regular tiled frame while retaining gaps; native `fill` would bypass those gaps. Fullscreen ignores outer gaps.

## Effects and gestures

Global animations, gradient focus borders, subtle glow, and tab-rail app icons are enabled.

| Input | Effect |
| --- | --- |
| Main: Option + backtick | Toggle the sliding glass Quake terminal; it hides on focus loss. |
| Three-finger vertical swipe | Switch workspaces with animated settling. |
| Three-finger horizontal swipe | Momentum-scroll Niri columns. On vertical monitors, scrolling follows the primary axis and workspace swipes use the perpendicular axis. |
| Option + left-drag / right-drag | Swap tiled windows / resize. |

Captured workspace swipe previews require OmniWM Screen Recording permission. Keyboard workspace jumps are immediate in 0.7.6; its workspace transition animation is gesture-only. Clickless window move/resize gestures remain disabled to avoid conflicting with ordinary scrolling.

Overview and its shortcut/gesture are disabled because the search bar overlaps the camera notch in 0.7.6. There is no search-only hide or offset setting. Leave Finder → Applications → OmniWM → Get Info → **Scale to fit below built-in camera** unchecked: that compatibility mode wastes the space beside the notch. This macOS preference is outside the dotfiles. Re-enable Overview only after its placement is fixed upstream. Niri scrolling and workspace swipe previews are independent of Overview.

## Implementation and maintenance

The AeroSpace bindings remain native. OmniWM's workspace renderer and singleton Lua/libuv stream follow the AeroSpace implementation, reusing its display measurements and atomic writes. The general `config/skhd/skhdrc` loads shared application shortcuts from `apps` and the selected backend's bindings from `wm`. Backend bindings live in `config/aerospace/skhdrc` and `config/omniwm/skhdrc`.

`~/.config/wm/backend` selects the backend, and `~/.config/skhd/wm` links to its bindings. The shared skhd entry point stays unchanged when switching. The linked `wm.sh`, `wm-mode.py`, and `wm-window.py` are runtime helpers. Mode callbacks use kernel process start times to reject stale labels, and SketchyBar reads the saved mode. Help, Reload, and Pause use full Main aliases instead of synthesized Escape. Window-state changes are serialized to keep floating and tiling actions consistent.

SketchyBar owns `monitorGapOverrides` and regenerates connected-monitor top gaps after startup, display changes, and wake. Keep shared margins in `[gaps]`; do not maintain per-monitor overrides manually. The updater recognizes GUI-serialized tables even if comments were removed. As with AeroSpace, generated gaps update the linked source file and can produce a local diff; review those generated changes before committing.

The CLI is resolved from the app bundle or PATH. `DOTFILES_OMNIWMCTL` overrides its executable for the dispatcher. No additional third-party scripting dependencies are required beyond the existing SketchyBar runtime.
