-- Use the same isolated LuaRocks tree as scripts/lua-setup.sh.
local tree = os.getenv('DOTFILES_LUA_TREE') or os.getenv('HOME') .. '/.local/share/dotfiles-lua'
assert(_VERSION == 'Lua 5.5', 'SketchyBar requires Lua 5.5; run scripts/lua-setup.sh')
package.path = tree .. '/share/lua/5.5/?.lua;' .. tree .. '/share/lua/5.5/?/init.lua;' .. package.path
package.cpath = tree .. '/lib/lua/5.5/?.so;' .. package.cpath
return tree
