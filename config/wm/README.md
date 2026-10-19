# Window manager configuration

Shared settings live in `config/omniwm/settings.shared.toml` and `config/aerospace/aerospace.shared.toml`. Edit these for portable preferences and shortcuts.

Each backend also has an ignored `monitors.local.toml` next to its shared settings. These contain machine-specific screen information and are created on installation. The current machine's measurements are preserved there. SketchyBar updates the local files when displays change, on wake, or on startup. Returning to Main only changes the mode indicator; routine stream health checks do not replay display measurements.

For OmniWM, local settings support the five `monitor*Overrides` arrays. For example:

```toml
[[monitorGapOverrides]]
id = "YOUR-DISPLAY-UUID"
monitorName = "External display"
monitorDisplayUUID = "YOUR-DISPLAY-UUID"
outerGapTop = 38.0
```

The local `[workspace-monitor-assignments]` section overrides individual workspace monitor roles (`main`, `secondary`, or `tertiary`). The composer merges these into the generated native workspace tables:

```toml
[workspace-monitor-assignments]
"7" = "secondary"
"8" = "secondary"
"9" = "secondary"
```

OmniWM's current local configuration assigns workspaces 1–6 to the main display and 7–9 to the second display, which keeps an active workspace even when empty. With one connected display all workspaces fall back to the main display. Fresh OmniWM local files use this same default. Move mode's 1–9 keys transfer individual windows and follow them.

For AeroSpace, local settings support the measured top gap and optional workspace monitor assignments:

```toml
[gaps]
outer.top = [{ monitor."1" = 6 }, { monitor."2" = 35 }, 38]

[workspace-to-monitor-force-assignment]
"9" = ["secondary", "main"]
```

SketchyBar owns OmniWM's gap override array and AeroSpace's `outer.top`; monitor-specific layout overrides and workspace assignments remain editable.

The Lua composer generates ignored `settings.toml` and `aerospace.toml` files, which the installed configuration links already point to. Do not edit the generated files: regeneration replaces them, including edits written by OmniWM's Settings UI. Put lasting changes in the shared or local source instead.

Run `lua scripts/wm-config.lua all` from the repository to regenerate both configs without starting a window manager. Installation, service startup, and the Admin mode reload action also generate the required config. OmniWM watches its generated file; for a running AeroSpace, follow manual generation with `aerospace reload-config`.

Run `lua scripts/wm-close.lua --dry-run` to show the planned close and successor IDs without changing windows.

SketchyBar's backend plugins live in `plugins/omniwm/` and `plugins/aerospace/`; shared backend selection, config composition, and display measurements live in `plugins/wm/`. Unchanged properties are cached to avoid repeated IPC updates. Workspace requests highlight their pill immediately, with native events confirming the active workspace; transient query failures retain the last valid pills. Volume uses native events, and Bluetooth checks once per minute plus hover and wake.
