# macOS dotfiles

My macOS setup for terminal work, C/C++/Python/Rust development, keyboard-driven window management, and Chinese input. These configurations bring my everyday tools together into a consistent workflow.

## Terminal configs

[Ghostty](config/tty/ghostty/config.ghostty) and [Kitty](config/tty/kitty/kitty.conf) share the pinned `TenofHearts/tty-config` submodule at `config/tty`. Link the terminal you use:

```sh
./install.sh --only ghostty          # Link only the shared Ghostty profile and shader
python3 scripts/links.py status --only ghostty
ghostty +validate-config

./install.sh --only kitty            # Link Kitty only; leave Ghostty alone
```

Ghostty and Kitty use `Ctrl+Shift+C` and `Ctrl+Shift+V` for clipboard copy and paste. Plain `Ctrl+C`, `Ctrl+A`, and `Ctrl+V` go to the foreground program. This keeps interrupt, the tmux prefix, and Neovim visual block mode available. To reload an open Ghostty session on macOS, press `Cmd+Shift+,`.

Ghostty's native right-click copies selected text or pastes the system clipboard. Kitty keeps its default mouse bindings. In tmux, drag to copy as usual and right-click a shell pane to paste the latest tmux buffer.

Optional overrides: `~/Library/Application Support/com.mitchellh.ghostty/local.ghostty` for Ghostty and `~/.config/kitty/local.conf` for Kitty.

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

`--only APP` also supports aerospace, omniwm, skhd, sketchybar, wm (shared WM helpers), zsh, oh-my-posh, cowsay, ghostty, kitty, vscode, git, homebrew (Brewfile), nvim, tmux, freerdp, karabiner, keyboard-layouts, and rime. For example, `./install.sh --only ghostty --dry-run`. The same selections work with `scripts/links.py status`. Only the selected app's submodule is initialized; WM settings are generated only for WM-related selections.

Full installation also initializes submodules and installs the Codex profile. Existing destinations are skipped by default. Use `./install.sh --force` (or `./install.sh --only codex --force`) to delete conflicting destinations and install fresh links, without backups. This includes stale or broken symlinks, regular files, and directories. Correct links are preserved. Add `--dry-run` to preview changes. Reload Zsh after installing the shell configuration to enable the alias.

## Git

My [Git configuration](config/git) keeps version-control behavior consistent across projects and filters out common machine-generated clutter.

## Karabiner-Elements

[Karabiner-Elements](config/karabiner/karabiner.json) uses logical Ctrl (after per-keyboard modifier placement) for GUI editing. `Ctrl+C/X/V/A`, `Ctrl+Z/Y`, and `Ctrl+S/F/O/P` copy, cut, paste, select all, undo/redo, save, find, open, and print. Terminal apps and remote Windows sessions are excluded. Both Command keys still support the local `Cmd+L` screen lock outside an active remote session.

- Clipboard history: bind Raycast's **Clipboard History** command to `F18`. Press `Cmd+V` to open it in local apps, including terminals. `Ctrl+V` still pastes in GUI apps, `Ctrl+Shift+V` pastes in terminals, and remote clients keep their native keys.
- Browsers: `Ctrl+T/W/L` for new tab, close tab, and address bar; `Ctrl+Tab` / `Ctrl+Shift+Tab` to cycle tabs; `F5`, `F12`, and `Ctrl+H` for reload, developer tools, and history; `Alt+Left/Right` for back/forward.
- Finder: `F2` renames, `Enter` opens, `Backspace` goes back, and forward `Delete` moves items to Trash. To move files, copy them with `Ctrl+C`, then press `Option+Cmd+V` in the destination. Filename and search fields keep normal text editing.
- VS Code: `./install.sh --only vscode` links [keybindings.json](config/vscode/keybindings.json) for the default profile. The editor uses native Command shortcuts; the terminal pane translates them back to Ctrl. Both `Ctrl+C` and physical `Cmd+C` therefore send interrupt there; use `Ctrl+Shift+C` to copy. If you already have a personal keybindings file, the installer skips it; merge the bindings instead of using `--force`.

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
