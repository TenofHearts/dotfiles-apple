local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'front_app', {position='left',
  icon={drawing=false}, label={max_chars=28, padding_left=0}})
local version = 0
item:subscribe('front_app_switched', function(env) version = version + 1; util.set(item, {label=env.INFO}) end)
item:subscribe({'forced', 'system_woke'}, function()
  local current = version
  util.macos([[ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.frontmostApplication.localizedName.js;]],
    function(result, code)
      if code == 0 and current == version then util.set(item, {label=util.trim(result)}) end
    end)
end)
