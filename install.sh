#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This installer requires macOS.' >&2
  exit 1
fi
if [[ ${1:-} == --bootstrap ]]; then
  shift
  "$ROOT/scripts/bootstrap.sh"
fi
exec python3 "$ROOT/scripts/links.py" install "$@"

