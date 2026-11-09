# Window manager configuration

OmniWM uses `config/omniwm/settings.shared.toml` to seed a new installation. Its ignored `settings.toml` stores GUI and CLI preferences; startup, reload, and wake preserve it. SketchyBar updates only measured per-display `outerGapTop` values.

OmniWM 0.8.0 automatically migrates native settings to schema 5 and saves an exact `~/.config/omniwm/settings.toml.pre-v5` backup. Do not rebuild just to upgrade. The migration renames six native resize hotkey actions; our skhd CLI bindings need no changes. Empty monitor override arrays may disappear when OmniWM saves the file. Restore the backup before downgrading to 0.7.6.

AeroSpace regenerates its ignored `aerospace.toml` from `config/aerospace/aerospace.shared.toml` and `monitors.local.toml`. Keep lasting AeroSpace changes in those source files.

AeroSpace uses the original fixed `outer.top = 5`, below the usable screen area provided by macOS. SketchyBar only adjusts its own bar height and never changes AeroSpace gaps. Legacy measured top gaps in local settings are ignored.

Each backend has an ignored `monitors.local.toml` for machine-specific screen settings. OmniWM's local defaults assign workspaces 1–6 to the main display and 7–9 to the secondary display, falling back to the main display when only one is connected. Change existing OmniWM assignments through its GUI or native settings.

Run `lua scripts/wm-config.lua all` to create missing OmniWM settings and regenerate AeroSpace's config. For a running AeroSpace, follow generation with `aerospace reload-config`.


Run `lua scripts/wm-config.lua omniwm --rebuild` to replace saved OmniWM preferences with shared/local defaults. Back up `settings.toml` first if you want to retain GUI customizations.
