# macOS dotfiles

Personal macOS setup for a Zsh terminal, C/C++/Python/Rust development in Neovim, window management, keyboard remapping, and Chinese input with Squirrel/Rime Ice. Homebrew supplies dependencies; a Python installer links configuration files and backs up anything it replaces.

## Quick start

Requires macOS, Git, and Python 3. Keep the checkout in a permanent location: installed configurations link back to it.

```sh
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-apple.git dotfiles
cd dotfiles

# Preview configuration changes without writing anything.
./install.sh --dry-run

# Install dependencies, prepare Rime Ice, and link configurations.
./install.sh --bootstrap
```

If Command Line Tools are missing, bootstrap opens their installer and exits. Finish installing them, then rerun the command. Homebrew installation may request administrator access. Bootstrap installs missing Brewfile packages without upgrading existing ones and skips GUI apps when their expected installation paths already exist.

For an existing checkout, initialize Neovim with `git submodule update --init --recursive`. If dependencies and Rime Ice are already installed, use `./install.sh` to install only the links. Put `--bootstrap` first when combining flags; `./install.sh --bootstrap --dry-run` still installs dependencies, so use the plain dry run above to preview only.

After installation:

1. Open a new terminal. Override the committed Git identity in `~/.gitconfig.local`:
   ```ini
   [user]
       name = Your Name
       email = you@example.com
   ```
2. Open Karabiner-Elements and AeroSpace, complete their requested macOS permissions, and restart Karabiner after linking.
3. Start skhd with `./scripts/skhd-service.sh start`, grant Accessibility access, then run `./scripts/skhd-service.sh restart`.
4. Enable Squirrel in macOS input sources and choose **Deploy** from its menu. Log out and back in if the input method or custom keyboard layout is not available yet.
5. Install a Node.js version with `fnm install --lts` and select it with `fnm use lts-latest` in a shell where fnm is initialized. Pyright needs Node/npm; bootstrap installs fnm but does not install Node. The current Zsh fnm initialization checks `/opt/homebrew/opt/fnm/bin`; Intel users should add suitable initialization to `~/.zshrc.local`.
6. Follow the [Neovim README](config/nvim/README.md) for editor requirements and first-run setup.

Check the links with:

```sh
python3 scripts/links.py status
```

## Repository structure

```text
.
├── Brewfile                 # Homebrew CLI tools, apps, and Nerd Font
├── install.sh               # macOS entry point
├── scripts/
│   ├── bootstrap.sh         # Homebrew, packages, Rust, and Rime Ice setup
│   ├── links.py             # Install, inspect, and restore symlinks
│   └── rime-setup.py         # Add a pinned Rime Ice baseline
├── config/
│   ├── aerospace/           # Tiling window manager configuration
│   ├── cowsay/              # Terminal welcome artwork
│   ├── ghostty/             # Terminal font and colors
│   ├── git/                 # Shared Git defaults and global ignores
│   ├── karabiner/           # Keyboard and remote-session remapping
│   ├── keyboard-layouts/    # QWERTY layout without Option characters
│   ├── nvim/                # Separate, pinned Neovim Git submodule
│   ├── oh-my-posh/          # Prompt theme
│   ├── rime/                # Rime/Squirrel customization patches
│   ├── skhd/                # Independent hotkey daemon configuration
│   ├── tmux/                # Separate, pinned tmux Git submodule
│   └── zsh/                 # Login and interactive shell configuration
├── docs/                    # Reserved for additional documentation
└── tests/test_links.py      # Installer regression tests
```

## Scripts

Run these commands from the repository root.

| Script | Usage | Behavior |
| --- | --- | --- |
| `install.sh` | `./install.sh [--bootstrap] [--dry-run] [--home PATH]` | Requires macOS and an initialized Neovim submodule. Optionally runs bootstrap, then forwards remaining arguments to `links.py install`. |
| `scripts/bootstrap.sh` | `bash scripts/bootstrap.sh` | Prepares Command Line Tools/Homebrew, installs the Brewfile, selects the minimal Rust profile, ensures stable Rust and `rust-analyzer`, `rust-src`, `rustfmt`, and `clippy`, then runs Rime setup. Does not create configuration links. |
| `scripts/skhd-service.sh` | `./scripts/skhd-service.sh start\|stop\|restart` | Manages skhd independently after its package and configuration are installed. |
| `scripts/links.py` | `python3 scripts/links.py install\|status\|restore ...` | Uses only the Python standard library. Installs backed-up relative symlinks, reports link status, or restores a recorded installation. See examples below. |
| `scripts/rime-setup.py` | `python3 scripts/rime-setup.py` | Copies missing, non-hidden Rime Ice files into `~/Library/Rime` from commit `3aea6d3694fb3d94ec663641f021f788822897ad`. Skips upstream `*.custom.yaml` files and existing destinations. If `rime_ice.schema.yaml` exists, leaves the entire baseline unchanged. |
| `tests/test_links.py` | `python3 -m unittest discover -s tests -v` | Tests backup/restore, repeated installation, dry runs, Rime data isolation, changed-file protection, symlinked parents, and dangling links in temporary homes. |

### Link installation and restore

```sh
python3 scripts/links.py install --dry-run
python3 scripts/links.py install
python3 scripts/links.py status

# Use the exact manifest path printed by installation.
python3 scripts/links.py restore /path/to/backup/manifest.json --dry-run
python3 scripts/links.py restore /path/to/backup/manifest.json

# Exercise link installation in an alternate home directory.
python3 scripts/links.py install --home /tmp/dotfiles-demo
python3 scripts/links.py status --home /tmp/dotfiles-demo
```

Backups and their manifests live under `~/.local/state/dotfiles/backups/<timestamp>/`. Correct links are left alone; conflicting files, directories, and dangling links are moved into the backup. The installer checks sources and rejects symlinked parent directories before linking, and attempts rollback if linking fails. `status` returns 0 when all links match and 1 otherwise.

Restore reads the destinations stored in the manifest; `--home` does not redirect restoration. It removes installed links and returns original files, refusing to overwrite destinations changed since installation. Restore does not uninstall Homebrew packages, undo Rust setup, remove Rime baseline files.

Neovim and Karabiner are linked as whole directories. Existing Karabiner `assets` and `automatic_backups` are copied into the checkout before replacement; conflicting runtime directories require manual review. Rime links only the customization patches, keeping dictionaries and learned data local. GNU Stow is included in the Brewfile, but installation uses `links.py`.

## Configuration purposes and principles

### Zsh

[Zsh](config/zsh) makes everyday navigation and development convenient through completion, history, and shell shortcuts. Optional integrations load only when their tools are available, so the shell remains usable without the full dependency set. Shared defaults stay in the repository; machine-specific paths, environment variables, and preferences belong in `~/.zprofile.local` and `~/.zshrc.local`.

The command line uses vi bindings: start typing in insert mode, press `Esc` for normal mode, and `i` or `a` to resume inserting. Open a new shell or run `exec zsh` after changing the configuration.

Directory jumping uses zoxide with `j` (for example, `j dotfiles`) and `ji` for interactive selection through fzf.

Interactive terminal shells automatically attach to tmux session `main`. Set `export DOTFILES_TMUX=0` in `~/.zprofile.local` to disable before tmux starts.

### Oh My Posh

[Oh My Posh](config/oh-my-posh/theme.omp.json) keeps development and shell context visible at the prompt. The theme groups information across multiple lines so project state and system context are easy to scan while leaving a clear place to type commands. Its typography works together with Ghostty's Nerd Font.

### cowsay

[cowsay](config/cowsay) adds a personal welcome to interactive terminals. The artwork is a small cosmetic layer rather than a dependency of the shell: it appears only when the required tools are available and stays out of scripted shell use. Set `export DOTFILES_WELCOME=0` in `~/.zshrc.local` to disable it.

### Ghostty

[Ghostty](config/ghostty/config.ghostty) uses a minimal visual configuration focused on legibility and support for the prompt's glyphs. Font and colors establish a consistent terminal appearance, while other behavior follows the application's defaults. The principle is to customize what matters to this workflow without maintaining a large terminal configuration.

### Git

[Git](config/git) favors predictable history changes and keeps machine-generated clutter out of repositories. Shared behavior belongs in the tracked configuration, while personal identity and machine-specific overrides can live in `~/.gitconfig.local`. This separates reusable workflow defaults from the settings each user or machine needs to supply.

### Neovim

[Neovim](config/nvim/README.md) is maintained as an independent, pinned submodule so the editor configuration can evolve separately and be reused across platforms. See its own README for setup, usage, and configuration principles.

[tmux](config/tmux/README.md) is also maintained as a pinned submodule. The Brewfile installs tmux, and the installer links `~/.tmux.conf` to `config/tmux/.tmux.conf`. Its prefix is `Ctrl-a`, with mouse support and `Alt` + arrow keys for switching panes.

### Karabiner-Elements

[Karabiner-Elements](config/karabiner/karabiner.json) adapts modifier placement to familiar keyboard habits and makes Windows remote sessions fit that arrangement. Remote-session adjustments are scoped to the remote view so local macOS interactions retain their intended behavior. Device-specific mappings account for different keyboard layouts and may need adapting when the hardware changes.

### Squirrel / Rime Ice

[Squirrel / Rime Ice](config/rime) supports Chinese input alongside an English-first development workflow. Small customization patches define input behavior and presentation over a separately installed upstream baseline. Dictionaries, learned words, and generated data remain local rather than becoming part of the dotfiles. This keeps preferences reproducible without replacing personal input history. Deploy Squirrel after changing the patches.

### Custom keyboard layout

The [custom keyboard layout](config/keyboard-layouts) preserves familiar QWERTY typing while freeing Option combinations for shortcuts instead of special-character input. It complements the modifier remapping and gives Squirrel a consistent keyboard layout to use.

### AeroSpace

[Configuration](config/aerospace/aerospace.toml) · [Hotkey reference](config/aerospace/help.html)

Installed through the Brewfile. Launch AeroSpace and grant Accessibility access when prompted. Reload configuration with `aerospace reload-config`.

### skhd

[Configuration](config/skhd/skhdrc)

skhd is an independent hotkey daemon with its own Homebrew package, configuration directory, Accessibility permission, and launchd service. Bootstrap installs the package; the link installer installs `~/.config/skhd`. Start the service separately after linking:

```sh
./scripts/skhd-service.sh start
# Grant skhd Accessibility access in System Settings, then:
./scripts/skhd-service.sh restart
```

Use `./scripts/skhd-service.sh stop` to stop it. The script locates skhd through PATH or either standard Homebrew prefix and checks that its configuration is installed before starting. Bootstrap and link installation do not start background services.

The current left Option shortcuts (after Karabiner remapping) call AeroSpace commands directly: H/J/K/L focus, 1–9 select workspaces, M minimizes, Q closes, and Shift + semicolon toggles Command mode. These bindings live only in skhd; AeroSpace retains the plain keys in its modes. Right Option alone does not activate these shortcuts. Other application shortcuts can be added to skhd independently. Reload skhd with `skhd --reload` after editing its configuration; reload AeroSpace separately with `aerospace reload-config` after editing its bindings.

### SketchyBar

[Configuration](config/sketchybar)

Installed through the Brewfile. Enable **Displays have separate Spaces** in macOS settings. Start with `brew services start sketchybar`, stop with `brew services stop sketchybar`, and reload configuration with `sketchybar --reload`. Plugins use SbarLua on Lua 5.5. Bootstrap installs pinned modules with LuaRocks; rerun `bash scripts/lua-setup.sh` to repair them.
