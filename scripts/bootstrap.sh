#!/bin/bash
# Install dependencies. Homebrew's installer may request administrator access.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
usage() {
  echo 'Usage: ./scripts/bootstrap.sh [--dry-run]'
  echo 'Install macOS software and its dependencies. Run ./install.sh separately to link configurations.'
}
dry_run=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --dry-run) dry_run=1 ;;
    *) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done
if [[ $(uname -s) != Darwin ]]; then
  echo 'This installer requires macOS.' >&2
  exit 1
fi
if [[ $dry_run == 1 ]]; then
  echo 'Install Xcode Command Line Tools and Homebrew if missing.'
  echo "Run brew bundle install --file=\"$ROOT/Brewfile\" --no-upgrade."
  echo 'Set up SketchyBar Lua modules, Rust tools and the pinned Rime Ice baseline.'
  exit 0
fi
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo 'Finish installing Command Line Tools, then rerun ./scripts/bootstrap.sh.'
  exit 1
fi
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  installer=$(mktemp)
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  /bin/bash "$installer"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
# Respect manually installed apps instead of replacing their installations.
skip=${HOMEBREW_BUNDLE_CASK_SKIP:-}
[[ ! -d /Applications/Ghostty.app ]] || skip="$skip ghostty"
[[ ! -d /Applications/AeroSpace.app ]] || skip="$skip aerospace"
[[ ! -d /Applications/OmniWM.app ]] || skip="$skip omniwm"
[[ ! -d /Applications/Karabiner-Elements.app ]] || skip="$skip karabiner-elements"
[[ ! -d '/Library/Input Methods/Squirrel.app' && ! -d "$HOME/Library/Input Methods/Squirrel.app" ]] || skip="$skip squirrel"
export HOMEBREW_BUNDLE_CASK_SKIP="$skip"
brew bundle install --file="$ROOT/Brewfile" --no-upgrade
"$ROOT/scripts/lua-setup.sh"
# Minimal Rust: no local documentation. Extra components serve Neovim.
export PATH="$(brew --prefix rustup)/bin:$PATH"
rustup set profile minimal
if ! rustup run stable rustc --version >/dev/null 2>&1; then
  rustup toolchain install stable --profile minimal
fi
if ! rustup show active-toolchain >/dev/null 2>&1; then
  rustup default stable
fi
rustup component add --toolchain stable rust-analyzer rust-src rustfmt clippy
python3 "$ROOT/scripts/rime-setup.py"
