local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'volume', {position='right'})
local version = 0
local function set(volume)
  volume = tonumber(volume)
  if not volume then return end
  local icon = volume >= 60 and '󰕾' or volume >= 30 and '󰖀' or volume > 0 and '󰕿' or '󰖁'
  item:set({icon=icon, label=volume .. '%'})
end
item:subscribe('volume_change', function(env) version = version + 1; set(env.INFO) end)
item:subscribe({'forced', 'system_woke'}, function()
  local current = version
  util.exec("/usr/bin/osascript -e 'output volume of (get volume settings)'", function(result, code)
    if code == 0 and version == current then set(result) end
  end)
end)
