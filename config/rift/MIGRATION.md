# Rift / AeroSpace comparison

Rift 0.7.0 follows the existing AeroSpace keyboard workflow. It currently uses its
own virtual workspaces inside native macOS Spaces. Animations, workspace gestures,
overview, stack tabs, modifier dragging, and focus-follows-mouse remain disabled.

## Configuration structure

- `config.toml`: settings, gaps, window rules, then Command / Move / Join / Adjust / Admin modes.
- `help.html`: the shortcut guide opened with Command mode → ?.
- `scripts/join.lua`: the small compatibility helper for AeroSpace-style joins.
- `scripts/cycle-layout.lua`: cycle the active workspace through the six layouts.
- `../skhd/skhdrc`: shared Left Option shortcuts; plain mode keys stay in each WM.
- `../window-manager/manager`: the selected manager (`aerospace` or `rift`).
- `../window-manager/hotkey.sh`: direct dispatch for frequent shortcuts.
- `../window-manager/control.py`: shared switching, pause/resume, and explicit-tiling helper.
- `../sketchybar/plugins/{aerospace,rift}.lua`: the manager-specific bar integrations,
  each backed by a persistent event stream. Display-gap measurement is shared.

Rift requires `config.toml`; its default mode is named `default` rather than
AeroSpace's `main`. These names are native format requirements.

## Switching

From the dotfiles checkout:

```sh
./scripts/window-manager.sh aerospace
./scripts/window-manager.sh rift
```

The script stops the other manager before starting the requested one, saves the
selection, and reloads skhd and SketchyBar. Run it without an argument to apply a
manually edited `config/window-manager/manager` setting. Startup failures attempt
to restore the previous selection and manager.

The managers maintain separate layouts. Switching does not convert an AeroSpace
layout tree into Rift's tree or create native macOS desktops from virtual workspaces.

## Working equivalents

- Left Option H/J/K/L focuses; 1–9 selects workspaces; Q closes. Left Option M sends
  the system Command M minimize shortcut directly through skhd for either manager.
- Left Option Shift+semicolon toggles Command mode from any native binding mode.
- Command → M/R/A selects Move/Adjust/Admin. Escape and Enter exit to Main, except
  Join returns to Move.
- Move H/J/K/L moves windows; 1–9 moves a window and follows it. Rift indices are
  zero-based internally and are mapped to the displayed names 1–9.
- Move → V → direction joins with a neighbor and returns to Move. The helper makes
  horizontal joins into vertical pairs and vertical joins into horizontal pairs.
  A missing neighbor leaves the layout unchanged. Complex existing groups still
  use Rift's own target-selection behavior.
- Shift H/J/K/L in Move uses Rift's native workspace-to-display command.
- Adjust F fills the screen without outer gaps, Shift+Space toggles the focused
  window’s floating state, and T explicitly tiles a floating window.
- Adjust 1–6 selects Traditional / BSP / Master-stack / Scrolling / Stack / Floating
  for the current workspace. Space cycles in that order and wraps to Traditional.
  Both stay in Adjust; Left Option 1–9 still selects workspaces.
- Stack offset is 20 logical points, reduced from 40 for a tighter stack.
- WeChat call windows and the configured browsers' picture-in-picture windows float.
- SketchyBar shows active/occupied workspaces and the current mode. It highlights
  workspace events immediately, caches display mapping, and coalesces native queries.
- Gap values match AeroSpace: 2 logical points inside, 5 around the sides/bottom,
  and a measured top gap. The updater subtracts Rift's already-reserved menu/notch
  inset. On the built-in Retina display, a logical point is two physical pixels.

## Differences intentionally retained

| Area | AeroSpace | Rift trial |
| --- | --- | --- |
| Adjust M | Native minimize | Omitted; Left Option M works in every mode |
| Resize H/J/K/L | 25-point steps | Native ~5% steps; floating-window resizing is ignored |
| Adjust A | Accordion / tiles | Native stack toggle; geometry/selection differ |
| Pointer on display change | Lazy center on the newly focused monitor | No equivalent callback configured; pointer warping stays off |
| Admin P | Disable management without exiting | Stop the Rift service; resume with `python3 ~/.config/window-manager/control.py resume` |
| Login | `start-at-login = false` | Native launch agent starts at login while Rift is selected; switching to AeroSpace removes that agent |
| Workspace scope | Globally named workspaces | Virtual-workspace sets within native Space/display contexts |
| Window/layout behavior | AeroSpace normalization, dialog rules, and monitor boundaries | Rift's native behavior; exact equivalence is not assumed |

Pause/resume currently starts a fresh Rift session rather than providing AeroSpace's
in-process management pause. The above differences were reviewed and left unchanged.

The broken Finder disk-image-root callback and helper were removed from AeroSpace;
there is no special disk-image floating rule in either manager.

## Remaining limits and possible improvements

- Multiple displays, native Space changes, sleep/wake, and reconnects need normal-use
  testing on the actual display arrangement. Workspace-to-display commands are
  configured, but only the built-in display was available for verification.
- Apps may refuse tile widths below their minimum size. With too many side-by-side
  windows, that can defeat a visible gap even though the layout requests 2 points.
- Rift 0.7.0 applies virtual-workspace transitions instantly. The animation setting
  controls other window/layout changes; native macOS Space transitions are separate.
- A future native-Spaces setup would need different numbered shortcuts, window-transfer
  behavior, and bar indicators. It is not enabled by this migration.
- Finder auto-floating could be reconsidered with a reliable window-targeting API;
  no replacement helper is installed now.

Migration-only test scripts and temporary source/layout snapshots were removed after
verification. The existing link-installer tests remain under `tests/`.
