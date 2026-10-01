#!/bin/bash
# Save Rectangle's current macOS preferences to this directory.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This script requires macOS.' >&2
  exit 1
fi

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$CONFIG_DIR/com.knollsoft.Rectangle.plist"
TEMP_FILE="$(mktemp "$CONFIG_DIR/.rectangle-export.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT

# Export and validate before replacing the existing snapshot.
defaults export com.knollsoft.Rectangle - > "$TEMP_FILE"
plutil -convert xml1 "$TEMP_FILE"
plutil -lint "$TEMP_FILE"
chmod 644 "$TEMP_FILE"
mv "$TEMP_FILE" "$DEST"

echo "Saved Rectangle settings to $DEST"
git -C "$CONFIG_DIR" diff -- com.knollsoft.Rectangle.plist
echo 'Review the diff, then commit when ready.'
