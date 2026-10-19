#!/usr/bin/env lua
local tree = os.getenv('DOTFILES_LUA_TREE') or os.getenv('HOME') .. '/.local/share/dotfiles-lua'
package.cpath = tree .. '/lib/lua/5.5/?.so;' .. package.cpath
local uv = require('luv')
local script = assert(uv.fs_realpath(arg[0]))
local root = assert(script:match('^(.*)/scripts/wm%-config.lua$'))
local config = dofile(root .. '/config/sketchybar/plugins/wm/config.lua')
local backend = arg[1] or 'all'
assert(backend == 'all' or backend == 'aerospace' or backend == 'omniwm', 'Expected aerospace, omniwm, or all')
for _, name in ipairs(backend == 'all' and {'aerospace', 'omniwm'} or {backend}) do
  local path = config.generate(name)
  print(path)
end
