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
| Homebrew | `~/.Brewfile` | `Brewfile` |
| Rectangle | `~/Library/Preferences/com.knollsoft.Rectangle.plist` | `config/rectangle/` |
| Karabiner | `~/.config/karabiner` | `config/karabiner/` |
| Rime | `~/Library/Rime/*.custom.yaml` (only files in this repository) | `config/rime/` |

Karabiner needs a **directory** symlink for its file watcher to reload edits reliably; its main `karabiner.json` is tracked. Existing assets and automatic backups are copied into ignored directories before linking; their originals remain in the backup. Put any future portable complex modifications directly in `karabiner.json`, or deliberately add their asset files to Git.

Rectangle uses macOS NSUserDefaults. Its main plist is linked as requested, but macOS may replace that link or cache old preferences. If settings fail to refresh, log out and back in. After changing Rectangle settings, quit Rectangle, run `python3 scripts/links.py status`, and if the link was replaced, copy the current plist back to `config/rectangle/com.knollsoft.Rectangle.plist`, convert it with `plutil -convert xml1`, then rerun the installer. Review the diff before committing. Reference: [Rectangle preferences](https://github.com/rxhanson/Rectangle#preferences-storage), [Karabiner symlinks](https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/).

Rime only links the three custom YAML files. Dictionaries, schemas, build output, installation IDs, sync data and learned words remain local. `custom_phrase.txt` currently matches upstream and is left local. The baseline revision is pinned in `scripts/rime-setup.py`; existing Rime Ice installations are never updated by bootstrap. Learned words require separate migration if desired.

## Personal settings

### zsh appearance and shortcuts

The shell is adapted from [TenofHearts/dotfiles](https://github.com/TenofHearts/dotfiles/tree/c84e0cba5178348868ac5fd24b0dcb878f417231): the three-line pastel Oh My Posh theme, completion menu, autosuggestions, syntax colors, and fortune/cowsay/lolcat welcome artwork. Ghostty's main configuration is linked at `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, using MesloLGM Nerd Font Mono and a dark background. The theme and cow artwork are linked under `~/.config/oh-my-posh/` and `~/.config/cowsay/`.

Git shortcuts: `g`, `ga`, `gc`, `gca`, `gpu`, `gpl`, `glg`. uv shortcuts: `uva` (add), `uvr` (run), `uvac` (activate the current directory's `.venv`), `uvi` (initialize a bare project without README or Git initialization). Unlike the old `uvi`, this never deletes `main.py`; `uv init --bare` also omits the Python-version pin and other starter metadata. Both groups load only when their software exists. `ll`, `la`, `l` use macOS colored `ls`, and `cls` clears the screen.

Cargo, Conda, Docker prompt integration, CUDA, Linux coursework paths, rbenv and fnm setup are omitted. The requested local proxy is enabled at `http://127.0.0.1:7897` for HTTP, HTTPS and all_proxy; the proxy app must be running for proxied commands. Override these variables in `~/.zshrc.local` as needed. Set `DOTFILES_WELCOME=0` there to suppress the welcome banner.

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
