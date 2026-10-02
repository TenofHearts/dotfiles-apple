#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This installer requires macOS.' >&2
  exit 1
fi
if [[ ! -f "$ROOT/config/nvim/init.lua" ]]; then
  echo 'Neovim submodule is not initialized. Run:' >&2
  echo "  git -C \"$ROOT\" submodule update --init --recursive" >&2
  exit 1
fi
if [[ ${1:-} == --bootstrap ]]; then
  shift
  "$ROOT/scripts/bootstrap.sh"
fi
exec python3 "$ROOT/scripts/links.py" install "$@"

