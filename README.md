# macOS dotfiles

My macOS setup for terminal work, C/C++/Python/Rust development, keyboard-driven window management, and Chinese input. These configurations bring my everyday tools together into a consistent workflow.

## Terminal configs

[Ghostty](config/tty/ghostty/config.ghostty) and [Kitty](config/tty/kitty/kitty.conf) share the pinned `TenofHearts/tty-config` submodule at `config/tty`. Link the terminal you use:

```sh
./install.sh --only ghostty          # Keep the macOS colors and load the shared profile
python3 scripts/links.py status --only ghostty
ghostty +validate-config

./install.sh --only kitty            # Link Kitty only; leave Ghostty alone
```

The [macOS Ghostty config](config/ghostty/config.ghostty) keeps the foreground and background colors. The shared profile sets the 12 pt 0xProto Nerd Font, cursor trail, and Ctrl-V paste. To reload an open Ghostty session, press `Cmd+Shift+,`.

`./install.sh` links configurations; it does not install apps or fonts. Add `--dry-run` to preview links. Software installation is separate: `./scripts/bootstrap.sh --dry-run` previews the full setup, and `./scripts/bootstrap.sh` runs it using the [Brewfile](Brewfile).

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

## AI agents

[Codex preferences](config/ai/README.md#codex-setup) are shared through the `TenofHearts/ai-config` submodule at `config/ai`, with a separate directory for each agent (`codex/` and `opencode/`). The submodule revision is pinned by this repository. The installer links `config/ai/codex/dotfiles.config.toml` to `~/.codex/dotfiles.config.toml`. The Zsh `cx` alias selects this profile with `codex --profile dotfiles`; machine-specific settings and authentication remain in `~/.codex/`.

```sh
./install.sh --only codex --dry-run  # Preview the Codex link
./install.sh --only codex           # Initialize its submodule and install the link
python3 scripts/links.py status --only codex
codex --profile dotfiles            # Also works before reloading Zsh
```

`--only APP` also supports aerospace, omniwm, skhd, sketchybar, wm (shared WM helpers), zsh, oh-my-posh, cowsay, ghostty, kitty, git, homebrew (Brewfile), nvim, tmux, freerdp, karabiner, keyboard-layouts, and rime. For example, `./install.sh --only ghostty --dry-run`. The same selections work with `scripts/links.py status`. Only the selected app's submodule is initialized; WM settings are generated only for WM-related selections.

Full installation also initializes submodules and installs the Codex profile. Existing destinations are skipped by default. Use `./install.sh --force` (or `./install.sh --only codex --force`) to delete conflicting destinations and install fresh links, without backups. This includes stale or broken symlinks, regular files, and directories. Correct links are preserved. Add `--dry-run` to preview changes. Reload Zsh after installing the shell configuration to enable the alias.

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

## FreeRDP

[FreeRDP shortcuts](config/freerdp/README.md) provide saved-machine selection with `rdp`, shared launch flags, and fullscreen by default. The standalone Linux/macOS configuration lives in the `config/freerdp` submodule. Install with `./install.sh --only freerdp`.

OpenCode: run `./install.sh --only opencode`, then reload Zsh and use `oc`. See [OpenCode setup](config/ai/README.md#opencode-setup) for the local API key and overlay behavior.
