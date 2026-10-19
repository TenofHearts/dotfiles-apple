# OmniWM

I use OmniWM as an alternative to AeroSpace for keyboard-driven window management. Tiled layouts and scrolling columns let me arrange windows to suit different tasks, while gestures and animations make desktop navigation more comfortable.

It works with skhd for my keyboard workflow and SketchyBar for workspace and mode information.

Option+H/J/K/L calls the native CLI directly in every skhd mode to keep focus switching responsive. These shortcuts use `/Applications/OmniWM.app`; `DOTFILES_OMNIWMCTL` can override the CLI path in skhd's environment.

Option+Q hands focus to another window in the active workspace before closing the original window by ID. Closing the last window keeps that workspace active. Save confirmations retain their focus. This applies to the managed close shortcut; app-specific close keys and window buttons retain OmniWM's native behavior.

[Shared configuration](settings.shared.toml) · [Local screen settings](../wm/README.md) · [Shortcut guide](help.html)

SketchyBar shows the focused window title followed by compact app icons in one rounded pill for the active workspace. The icons are display-only, with equal styling; hover for an app and title. They follow screen order from left to right, then top to bottom. More than six windows appear in an informational `+N` menu. The pill matches the workspace pills’ height and has no inner group borders.

OmniWM 0.7.6 does not expose hidden Dwindle tab membership or the exact split tree through IPC, or settings to hide tab rails or limit actual nesting depth. Spatial ordering follows the visible layout; ambiguous grids may differ from the internal tree.
