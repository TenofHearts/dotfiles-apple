#!/bin/bash
# Install dependencies. Homebrew's installer may request administrator access.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo 'Finish installing Command Line Tools, then rerun install.sh --bootstrap.'
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
[[ ! -d /Applications/Rectangle.app ]] || skip="$skip rectangle"
[[ ! -d /Applications/Karabiner-Elements.app ]] || skip="$skip karabiner-elements"
[[ ! -d '/Library/Input Methods/Squirrel.app' && ! -d "$HOME/Library/Input Methods/Squirrel.app" ]] || skip="$skip squirrel"
export HOMEBREW_BUNDLE_CASK_SKIP="$skip"
brew bundle install --file="$ROOT/Brewfile" --no-upgrade
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
