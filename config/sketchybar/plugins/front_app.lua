local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'front_app', {position='left', padding_left=12,
  icon={drawing=false}, label={font='SF Pro:Semibold:12.0', max_chars=28}})
local version = 0
item:subscribe('front_app_switched', function(env) version = version + 1; item:set({label=env.INFO}) end)
item:subscribe({'forced', 'system_woke'}, function()
  local current = version
  util.macos([[ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.frontmostApplication.localizedName.js;]],
    function(result, code)
      if code == 0 and current == version then item:set({label=util.trim(result)}) end
    end)
end)
