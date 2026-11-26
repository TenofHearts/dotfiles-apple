# macOS dotfiles

This repository sets up my macOS shell, development tools, keyboard, window managers, and Chinese input. The settings live in [config/](config/). I share the [terminal](config/tty), [tmux](config/tmux), [Neovim](config/nvim), [AI agent](config/ai), and [FreeRDP](config/freerdp) configurations with other machines as Git submodules.

## Usage

Clone the repository somewhere you intend to keep it. The installer creates symlinks back to this checkout.

```sh
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-apple.git
cd dotfiles-apple
```

On a new Mac, run `./scripts/bootstrap.sh` to install software and dependencies from the [Brewfile](Brewfile). Use `./scripts/bootstrap.sh --dry-run` to preview that step, or skip it if the dependencies are already installed.

```sh
./install.sh --dry-run           # Preview configuration links
./install.sh                     # Link the configurations
python3 scripts/links.py status  # Check the installed links
```

To install just one component, use `./install.sh --only tmux`. Check it with `python3 scripts/links.py status --only tmux`. Run `./install.sh --help` for the full list of components.

Existing configurations are skipped by default. **`--force` replaces conflicting files, directories, or symlinks without a backup.** Back them up yourself before using it.

After installation, open a new shell. The shared Zsh configuration provides `cx` for Codex, `oc` for OpenCode, and `rdp` for remote connections when their configurations are installed. Keep credentials and saved connections local. To start the selected window manager, run `./scripts/wm-service.sh start`; to change it, use `./scripts/wm-service.sh switch omniwm` or `./scripts/wm-service.sh switch aerospace`.
