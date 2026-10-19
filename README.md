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
2. Open Karabiner-Elements and your selected window manager, complete their requested macOS permissions, and restart Karabiner after linking. AeroSpace is the default; see the backend setup below for OmniWM.
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
│   ├── aerospace/           # AeroSpace backend configuration
│   ├── omniwm/              # OmniWM backend configuration and migration notes
│   ├── wm/                  # Backend selection defaults
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
| `install.sh` | `./install.sh [--bootstrap] [--wm aerospace\|omniwm] [--dry-run] [--home PATH]` | Requires macOS and an initialized Neovim submodule. Optionally runs bootstrap, then forwards remaining arguments to `links.py install`. |
| `scripts/bootstrap.sh` | `bash scripts/bootstrap.sh` | Prepares Command Line Tools/Homebrew, installs the Brewfile, selects the minimal Rust profile, ensures stable Rust and `rust-analyzer`, `rust-src`, `rustfmt`, and `clippy`, then runs Rime setup. Does not create configuration links. |
| `scripts/wm-service.sh` | `./scripts/wm-service.sh start\|stop\|restart` or `switch aerospace\|omniwm` | Starts only the selected manager; switching stops the old manager, backs up and changes backend links, opens the new app, and reloads running skhd/SketchyBar. |
| `scripts/skhd-service.sh` | `./scripts/skhd-service.sh start\|stop\|restart` | Manages skhd independently after its package and configuration are installed. |
| `scripts/links.py` | `python3 scripts/links.py install\|status\|restore\|select-wm ...` | Uses only the Python standard library. Installs backed-up relative symlinks, selects a WM backend, reports link status, or restores a recorded installation. See examples below. |
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

### Window manager backends

AeroSpace and OmniWM are installed through the Brewfile. Config links for both are installed together. AeroSpace remains the default; a normal reinstall retains the installed selection. Neither bootstrap nor link installation starts a manager or changes login items.

```sh
./install.sh --wm aerospace       # choose bindings and bar backend, without launching apps
./install.sh --wm omniwm
# With configs linked and apps installed, switch the running manager:
./scripts/wm-service.sh switch omniwm
./scripts/wm-service.sh switch aerospace
# Explicit lifecycle for the selected backend:
./scripts/wm-service.sh start
./scripts/wm-service.sh stop
./scripts/wm-service.sh restart
```

Use `switch` for a running desktop: selecting links with `--wm` alone does not stop an existing manager. Keep both apps' Start at Login settings off and start the selected backend explicitly. The switch checks that the destination app and config exist before stopping anything and refuses to launch it if the old manager will not quit. Failed link selection or launch attempts restore the previous selection and reopen it. Opening successfully does not establish that macOS permissions are granted. Existing windows are adopted by the destination manager; window-to-workspace assignments and tree state are not transferred between managers.

`~/.config/wm/backend` selects the SketchyBar plugin. The shared `~/.config/skhd/skhdrc` loads independent application shortcuts from `apps` and backend bindings from `wm`, a link to `config/aerospace/skhdrc` or `config/omniwm/skhdrc`. Backend selection leaves the shared entry point unchanged. The installer backs up older skhd directory links before migrating them to individual file links. For selection without process changes or unrelated link updates, use `python3 scripts/links.py select-wm --wm omniwm`; reload running skhd and SketchyBar after selecting manually. The installer uses the standard `~/.config` directory.

### AeroSpace

[Configuration](config/aerospace/aerospace.toml) · [Hotkey reference](config/aerospace/help.html)

Launch AeroSpace and grant Accessibility access when prompted. Reload configuration with `aerospace reload-config`.

### OmniWM

[Configuration](config/omniwm/settings.toml) · [Hotkey reference](config/omniwm/help.html) · [Setup and backend differences](config/omniwm/README.md)

Targets released OmniWM 0.7.6 (schema 4). OmniWM requires Apple Silicon, macOS 26+, Accessibility and Input Monitoring, and **Displays have separate Spaces** enabled. Config changes live-reload. The config enables IPC for the bundled `omniwmctl`, disables native hotkeys and the workspace bar, and uses the same skhd/SketchyBar structure as AeroSpace. Start skhd separately using the next section. Open OmniWM once to complete its permissions/start screen before switching your normal desktop to it.

Command → Move/Adjust/Admin uses skhd capture modes. OmniWM has no separate Join mode; Move H/J/K/L handles native join/extract operations. Workspaces 1–9, directional focus, move-and-follow, floating call/PiP rules, minimize, close, fullscreen, and measured SketchyBar gaps are adapted. Adjust → Space cycles the current workspace through Dwindle and Niri, staying in Adjust. Accordion layouts have no equivalent, so Adjust A is unbound and omitted from the hotkey guide. Resizing uses split ratios in Dwindle and 25-point steps in Niri, workspace transfers swap the two displays' active workspaces, and Dwindle groups use tabs. Admin P quits OmniWM; restart it to resume. See the backend notes for the complete mapping.

Overview is disabled because its search bar overlaps the camera notch in 0.7.6. Leave macOS's **Scale to fit below built-in camera** off for OmniWM to retain the space beside the notch. Niri scrolling and workspace swipe animations remain enabled.

### skhd

[Configuration](config/skhd/skhdrc)

skhd is an independent hotkey daemon with its own Homebrew package, configuration directory, Accessibility permission, and launchd service. Bootstrap installs the package; the link installer installs `~/.config/skhd`. Start the service separately after linking:

```sh
./scripts/skhd-service.sh start
# Grant skhd Accessibility access in System Settings, then:
./scripts/skhd-service.sh restart
```

Use `./scripts/skhd-service.sh stop` to stop it. The script locates skhd through PATH or either standard Homebrew prefix and checks that its configuration is installed before starting. Bootstrap and link installation do not start background services.

The left Option shortcuts (after Karabiner remapping) use the selected backend: H/J/K/L focus, 1–9 select workspaces, M sends the macOS minimize shortcut (Command + M), Q closes, and Shift + semicolon toggles Command mode. These bindings live in `config/aerospace/skhdrc` and `config/omniwm/skhdrc`; AeroSpace retains its plain mode keys natively, while OmniWM uses skhd modes. Right Option alone does not activate these shortcuts. Keep general skhd settings in `config/skhd/skhdrc` and independent application shortcuts in `config/skhd/apps`. Reload skhd with `skhd --reload` after editing its configuration; reload AeroSpace separately after editing its bindings (Admin mode → R).

### SketchyBar

[Configuration](config/sketchybar)

Installed through the Brewfile. Enable **Displays have separate Spaces** in macOS settings. Start with `brew services start sketchybar`, stop with `brew services stop sketchybar`, and reload configuration with `sketchybar --reload`. Plugins use SbarLua on Lua 5.5. Bootstrap installs pinned modules with LuaRocks; rerun `bash scripts/lua-setup.sh` to repair them.

SketchyBar selects the matching workspace plugin from `~/.config/wm/backend`. The OmniWM workspace and stream plugins copy the AeroSpace implementation, including event coalescing, occupancy updates, reconnects, singleton locking, and mode display. Display sizing reuses the AeroSpace menu measurements, gap calculation, wake settling, and atomic writes; OmniWM uses a managed `monitorGapOverrides` array with stable display UUIDs. SketchyBar owns that entire array and regenerates it after wake/display changes, including after GUI saves remove comments; put shared gap preferences in `[gaps]`. The mouse centers on the newly focused monitor through the OmniWM stream, so that behavior requires SketchyBar to be running.
