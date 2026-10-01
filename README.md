# macOS dotfiles

Portable zsh, Git, Homebrew, Rectangle, Karabiner and Rime settings, captured from this Mac.

## Install on another Mac

Clone this repository to a permanent location, then run:

```sh
./install.sh --bootstrap
```

Bootstrap installs Homebrew if necessary, restores the Brewfile without upgrading existing packages, installs a pinned Rime Ice baseline when absent, and links the configuration. Complete any macOS installer dialogs, then rerun if needed. Manually installed Rectangle, Karabiner and Squirrel are preserved. Enable Squirrel in System Settings > Keyboard > Input Sources; grant Karabiner and Rectangle the permissions macOS requests. Use Squirrel's **Deploy** command after installing customizations.

On this Mac, or when dependencies are already installed:

```sh
./install.sh --dry-run
./install.sh
python3 scripts/links.py status
```

Quit Rectangle and Karabiner Settings before linking, then reopen them. Python 3 is required (included by bootstrap). The link installer uses the standard library for backups and rollback; Stow is also installed by the Brewfile, but should not separately manage these same paths.

## Managed paths

| App | Destination | Source |
| --- | --- | --- |
| zsh | `~/.zprofile`, `~/.zshrc` | `config/zsh/` |
| Git | `~/.gitconfig`, `~/.gitignore_global` | `config/git/` |
| Neovim | `~/.config/nvim` | `config/nvim/` |
| Homebrew | `~/.Brewfile` | `Brewfile` |
| Rectangle (manual import/export; no symlink) | `~/Library/Preferences/com.knollsoft.Rectangle.plist` | `config/rectangle/` |
| Karabiner | `~/.config/karabiner` | `config/karabiner/` |
| Rime | `~/Library/Rime/*.custom.yaml` (only files in this repository) | `config/rime/` |

Karabiner needs a **directory** symlink for its file watcher to reload edits reliably; its main `karabiner.json` is tracked. Existing assets and automatic backups are copied into ignored directories before linking; their originals remain in the backup. Put any future portable complex modifications directly in `karabiner.json`, or deliberately add their asset files to Git.

Rectangle uses macOS NSUserDefaults and must **not** be symlinked. Its tracked plist is a snapshot, restored separately after quitting Rectangle:

```sh
defaults import com.knollsoft.Rectangle "$PWD/config/rectangle/com.knollsoft.Rectangle.plist"
```

If migrating an old installation, remove only the symlink at `~/Library/Preferences/com.knollsoft.Rectangle.plist` before importing (keep its target in this repository). Reopen Rectangle after importing. Changes in the app are saved locally, not automatically to Git. To capture them, quit Rectangle and run:

```sh
./config/rectangle/export.sh
```

Rectangle also offers JSON import/export in its Preferences window. See [Rectangle preferences](https://github.com/rxhanson/Rectangle#preferences-storage).

Rime only links the three custom YAML files. Dictionaries, schemas, build output, installation IDs, sync data and learned words remain local. `custom_phrase.txt` currently matches upstream and is left local. The baseline revision is pinned in `scripts/rime-setup.py`; existing Rime Ice installations are never updated by bootstrap. Learned words require separate migration if desired.

## Personal settings

### zsh appearance and shortcuts

`j <part-of-directory-name>` uses autojump, as in the Linux configuration. It learns directories as you visit them with `cd`; its history stays local to each Mac. Homebrew installs autojump and zsh loads its integration automatically.

The shell is adapted from [TenofHearts/dotfiles](https://github.com/TenofHearts/dotfiles/tree/c84e0cba5178348868ac5fd24b0dcb878f417231): the three-line pastel Oh My Posh theme, completion menu, autosuggestions, syntax colors, and fortune/cowsay/lolcat welcome artwork. Ghostty's main configuration is linked at `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, using 0xProto Nerd Font and a dark background. The theme and cow artwork are linked under `~/.config/oh-my-posh/` and `~/.config/cowsay/`.

Git shortcuts: `g`, `ga`, `gc`, `gca`, `gpu`, `gpl`, `glg`. uv shortcuts: `uva` (add), `uvr` (run), `uvac` (activate the current directory's `.venv`), `uvi` (initialize a bare project without README or Git initialization). Unlike the old `uvi`, this never deletes `main.py`; `uv init --bare` also omits the Python-version pin and other starter metadata. Both groups load only when their software exists. `ll`, `la`, `l` use macOS colored `ls`, and `cls` clears the screen.

fnm is installed during bootstrap and initialized by the zsh configuration. Conda, Docker prompt integration, CUDA, Linux coursework paths and rbenv setup are omitted. The requested local proxy is enabled at `http://127.0.0.1:7897` for HTTP, HTTPS and all_proxy; the proxy app must be running for proxied commands. Override these variables in `~/.zshrc.local` as needed. Set `DOTFILES_WELCOME=0` there to suppress the welcome banner.

After installation, reload Ghostty's configuration or reopen it and run `exec zsh -l` in an existing shell. Bootstrap installs the prompt, plugins, font and welcome tools. The prompt falls back to a basic readable prompt if Oh My Posh is unavailable.

Identity is deliberately outside the repository. On each new Mac:

```sh
git config --file ~/.gitconfig.local user.name 'Your Name'
git config --file ~/.gitconfig.local user.email 'you@example.com'
```

Use `~/.zshrc.local` and `~/.zprofile.local` for private shell settings. Git uses Keychain credentials, fast-forward-only pulls and `main` as the default branch. Shell history stays local. The shell works on Intel and Apple Silicon.

Edit `Brewfile` to manage packages; `brew bundle --file ~/.Brewfile` restores them. Package versions are not locked by Homebrew. No global macOS defaults are changed beyond the listed application settings.

## Backups and rollback

Existing destinations are moved to `~/.local/state/dotfiles/backups/<timestamp>/` before linking, with a manifest. Repeated installs leave correct links untouched. Restore a specific installation using its printed manifest path:

```sh
python3 scripts/links.py restore ~/.local/state/dotfiles/backups/TIMESTAMP/manifest.json --dry-run
python3 scripts/links.py restore ~/.local/state/dotfiles/backups/TIMESTAMP/manifest.json
```

Restore refuses to overwrite paths changed since installation. Resolve those explicitly first; keep the backup until satisfied. Restore transactions newest first. Keep the repository in place while links are active. Backups and private identity files are not transferred with this project.

## Verification

```sh
python3 -m unittest discover -s tests
bash -n install.sh scripts/bootstrap.sh
zsh -n config/zsh/.zprofile config/zsh/.zshrc
plutil -lint config/rectangle/com.knollsoft.Rectangle.plist
```

## Neovim

The personal configuration starts from [Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim), revision `80743df53d8f7058fc5b60e41f1081d11df9c880`. Requires Neovim 0.12 or newer (uses built-in `vim.pack`), Git, ripgrep and fd. A compiler and make enable the optional native Telescope search extension. The existing Ghostty Nerd Font enables icons.

Run `nvim` after installing the configuration. Core features include Tokyo Night, Telescope search, Git change indicators, shortcut hints, statusline, surrounding/text objects, indentation detection and completion. C/C++, Python and Rust language support is configured in `config/nvim/lua/custom/languages.lua`. Completion includes language-server suggestions, buffer words, paths and snippets. No additional Tree-sitter parsers are installed. Save formatting is disabled.

Space is the leader key: `<Space>sf` searches files, `<Space>sg` searches text, `<Space>sh` searches help, `<Space>sn` searches the configuration, and `<Space>/` searches the current buffer. Use `:Tutor` to learn the basics. Edit `config/nvim/init.lua`; optional plugin examples live in `lua/kickstart/plugins/`.

Plugin versions are tracked in `config/nvim/nvim-pack-lock.json`. Review updates with `:lua vim.pack.update()` and apply them with `:write` in the update review buffer. Plugin downloads, caches, logs, undo history and Mason tools stay in Neovim's OS-specific data/state directories outside this repository.

The Lua configuration uses portable paths. On Linux link this directory to `~/.config/nvim`; on Windows place it at `%LOCALAPPDATA%\nvim`. This repository's installation script remains macOS-oriented. Install external dependencies separately on other operating systems, and select a Nerd Font (or set `have_nerd_font = false`).

### C/C++, Python and Rust

| Language | Completion / diagnostics | Manual formatter (`Space f`) |
| --- | --- | --- |
| C / C++ | clangd | clang-format |
| Python | Pyright (basic type checking) | Black (defaults) |
| Rust | rust-analyzer with `cargo clippy` | rustfmt |

Mason installs Pyright, Black and clang-format into Neovim's local data directory. Existing clangd is reused (Apple's command-line tools provide it on this Mac); Mason installs clangd only when absent. Pyright needs Node/npm, provided by the existing fnm setup. Python projects with `.venv` are detected automatically (including Windows); create one with `uv venv` or use `uv sync` for an existing uv project. `:LspPyrightSetPythonPath /path/to/python` selects another interpreter. Black uses its default formatting style unless the project configures it in `pyproject.toml`; no second Python diagnostic server is enabled. Rust uses default rustfmt settings unless the project supplies a rustfmt configuration.

Rust uses rustup's **minimal** stable profile, plus `rust-analyzer`, `rust-src` (standard-library navigation/completion), `rustfmt` and Clippy. Local Rust documentation, nightly toolchains, extra targets and debugger integrations are not installed. Bootstrap restores these components. For updates use `rustup update stable`.

Homebrew provides GNU GCC/G++ under versioned commands (currently `gcc-16` / `g++-16`); macOS `/usr/bin/gcc` and `/usr/bin/g++` remain Apple Clang. Homebrew's GCC bottle includes other GCC components such as Fortran; it does not offer a C/C++-only installation option. No full LLVM toolchain is installed for Neovim.

For larger C/C++ projects, supply `compile_commands.json` at the project root (or in `build/`) so clangd knows the actual compiler flags and include paths. On macOS, the configuration allows clangd to query trusted Homebrew GCC/G++ commands for their system include paths. On other systems, configure `--query-driver` for your trusted compiler if needed. Rust projects should contain `Cargo.toml`.

Useful mappings: `grd` definition, `grr` references, `grn` rename, `gra` code actions, `K` hover, `[d` / `]d` diagnostics, `Space f` format. Inspect tools with `:Mason`, attached servers with `:checkhealth vim.lsp`, and formatters with `:ConformInfo`.

Cargo shortcuts match the Linux dotfiles: `cg` Cargo, `cgi` initialize without Git, `cgn` create without Git, `cgb` build, `cgbr` release build, `cgr` run, `cgrr` release run, and `cga` add a dependency. The Linux `--vsc` typo is corrected to Cargo’s `--vcs`. Use `cg clippy`, `cg test`, `cg check` and `cg fmt` for the other commands. On macOS, interactive `gcc` / `g++` aliases select the newest installed Homebrew GNU compiler. Scripts should use the versioned commands explicitly or set `CC=gcc-16 CXX=g++-16`; aliases do not affect build tools. `EDITOR` and `VISUAL` use Neovim when installed.

Restart the terminal or run `exec zsh -l` to load the toolchain PATH and aliases. Rust-analyzer runs Clippy checks when saving; formatting for all three languages stays manual with `Space f`.

C/C++ defaults use four spaces, Allman block braces, an 80-column limit and traditional pointers (`int *pointer`). The style lives in `config/nvim/formatters/clang-format.yaml`; project `.clang-format` / `_clang-format` files take precedence. C/C++ Tab inserts four spaces, and indentation guessing is disabled for those filetypes. Python uses Black defaults; Rust uses rustfmt defaults.

Completion: Enter accepts a suggestion while the menu is visible and inserts a newline otherwise. Use Up/Down or Ctrl-N/Ctrl-P to choose, Ctrl-Space to open the menu, and Ctrl-E to dismiss it before inserting a newline.

File tree: `Space e` toggles Neo-tree on the left for the current working directory; `\` reveals the current file. Within the tree, Enter opens a file or expands a directory, `a` creates an entry, `r` renames, and `?` shows available actions. Use `:cd /path/to/project` to change the workspace root.

Automatic pairing inserts matching parentheses, square/curly brackets and quotes while typing. Enter remains controlled by completion.
