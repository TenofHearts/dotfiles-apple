# Homebrew supports both Apple Silicon and Intel Macs.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
# Homebrew rustup keeps its compiler/Cargo proxies in this directory.
[[ ! -d "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/rustup/bin" ]] ||
  export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/rustup/bin:$PATH"
[[ ! -d "${CARGO_HOME:-$HOME/.cargo}/bin" ]] ||
  export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
[[ -r ~/.zprofile.local ]] && source ~/.zprofile.local

