#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This installer requires macOS.' >&2
  exit 1
fi
bootstrap=0
if [[ ${1:-} == --bootstrap ]]; then
  shift
  bootstrap=1
fi
only=""
only_set=0
read_only=0
dry_run=0
for arg in "$@"; do
  if [[ $read_only == 1 ]]; then
    only="$arg"
    read_only=0
  else
    case "$arg" in
      --only) only_set=1; read_only=1 ;;
      --only=*) only_set=1; only="${arg#--only=}" ;;
      --dry-run) dry_run=1 ;;
    esac
  fi
done
if [[ $read_only == 1 || ( $only_set == 1 && -z "$only" ) ]]; then
  echo '--only requires an app name.' >&2
  exit 2
fi
if [[ $only_set == 1 ]]; then
  python3 - "$ROOT" "$only" <<'PYTHON'
import sys
sys.path.insert(0, sys.argv[1] + "/scripts")
from links import APPS
if sys.argv[2] not in APPS:
    print("Unknown app: " + sys.argv[2] + ". Choose: " + ", ".join(APPS), file=sys.stderr)
    sys.exit(2)
PYTHON
fi
if [[ $dry_run == 0 ]]; then
  if [[ $only == codex ]]; then
    git -C "$ROOT" submodule update --init --recursive -- config/ai
  elif [[ $only == nvim || $only == tmux ]]; then
    git -C "$ROOT" submodule update --init --recursive -- "config/$only"
  elif [[ -z "$only" ]]; then
    git -C "$ROOT" submodule update --init --recursive
  fi
  if [[ $bootstrap == 1 ]]; then "$ROOT/scripts/bootstrap.sh"; fi
  case "$only" in
    ""|wm|skhd) lua "$ROOT/scripts/wm-config.lua" all ;;
    aerospace|omniwm) lua "$ROOT/scripts/wm-config.lua" "$only" ;;
  esac
fi
exec python3 "$ROOT/scripts/links.py" install "$@"

