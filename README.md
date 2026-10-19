# macOS dotfiles

My macOS setup for terminal work, C/C++/Python/Rust development, keyboard-driven window management, and Chinese input. These configurations bring my everyday tools together into a consistent workflow.

## Ghostty

I use [Ghostty](config/ghostty/config.ghostty) as my terminal, with a readable font and colors that fit the rest of my setup.

## Zsh

[Zsh](config/zsh) is my everyday shell. Completion, command history, directory jumping, and familiar editing keys help me move around projects and work from the terminal.

## Oh My Posh

[Oh My Posh](config/oh-my-posh/theme.omp.json) gives my prompt a consistent appearance and keeps project and Git context visible while I work.

## cowsay

[cowsay](config/cowsay) adds a personal welcome when I open an interactive terminal.

## tmux

I use [tmux](config/tmux/README.md) to keep terminal sessions running and organize shells, editors, and commands into windows and panes.

## Neovim

[Neovim](config/nvim/README.md) is my development editor. I maintain its configuration separately so I can use the same editing workflow across machines and platforms.

## Git

My [Git configuration](config/git) keeps version-control behavior consistent across projects and filters out common machine-generated clutter.

## Karabiner-Elements

[Karabiner-Elements](config/karabiner/karabiner.json) adapts modifier placement to my keyboard habits and helps keep those habits consistent when working in remote Windows sessions.

## Squirrel / Rime Ice

I use [Squirrel with Rime Ice](config/rime) for Chinese input alongside my English-first development workflow. The configuration contains my input preferences and appearance customizations.

## Custom keyboard layout

My [keyboard layout](config/keyboard-layouts) keeps ordinary QWERTY typing while freeing Option combinations for shortcuts. It works together with Karabiner and my input method.

## Window management

I use AeroSpace and OmniWM as alternative window managers, with a familiar keyboard workflow for focusing, moving, and arranging windows across workspaces.

### AeroSpace

[AeroSpace](config/aerospace/aerospace.shared.toml) provides my tree-based tiling workflow. I use its modes to organize windows, adjust layouts, and move between tasks without reaching for the mouse.

[Shortcut guide](config/aerospace/help.html)

### OmniWM

[OmniWM](config/omniwm/settings.shared.toml) gives me both tiled layouts and scrolling columns. I use it with the same core keyboard habits, plus gestures and visual effects for navigating my desktop.

[Shortcut guide](config/omniwm/help.html)

[Local screen settings and config generation](config/wm/README.md)

## skhd

[skhd](config/skhd/skhdrc) handles my shared keyboard shortcuts and loads the bindings for the window manager I choose. This keeps application shortcuts consistent across both window managers.

## SketchyBar

[SketchyBar](config/sketchybar) keeps my workspaces, active window-manager mode, and everyday system information visible in a compact desktop bar.
