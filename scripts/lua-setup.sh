#!/bin/bash
# Install pinned SketchyBar modules into a dedicated LuaRocks tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TREE="${DOTFILES_LUA_TREE:-$HOME/.local/share/dotfiles-lua}"
LUA_PREFIX="$(brew --prefix lua)"
ROCKS=(luarocks --lua-version=5.5 --lua-dir="$LUA_PREFIX" --tree="$TREE")
for dependency in 'luv 1.52.1-0' 'luafilesystem 1.9.0-1' 'dkjson 2.11-1'; do
  read -r package version <<< "$dependency"
  if ! "${ROCKS[@]}" show "$package" "$version" >/dev/null 2>&1; then
    "${ROCKS[@]}" install "$package" "$version"
  fi
done
if ! "${ROCKS[@]}" show sbarlua 0.1.0-2 >/dev/null 2>&1; then
  "${ROCKS[@]}" build "$ROOT/scripts/rocks/sbarlua-0.1.0-2.rockspec" \
    LDFLAGS='-bundle -undefined dynamic_lookup -framework CoreFoundation'
fi
DOTFILES_LUA_TREE="$TREE" "$LUA_PREFIX/bin/lua" -e '
local tree = assert(os.getenv("DOTFILES_LUA_TREE"))
package.path = tree .. "/share/lua/5.5/?.lua;" .. tree .. "/share/lua/5.5/?/init.lua;" .. package.path
package.cpath = tree .. "/lib/lua/5.5/?.so;" .. package.cpath
for _, name in ipairs({"sketchybar", "luv", "lfs", "dkjson"}) do assert(require(name)) end
'
