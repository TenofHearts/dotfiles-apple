local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'volume', {position='right', update_freq=5, label='0%'})
local version = 0
-- Read mute separately: macOS retains the previous output level while muted.
item:subscribe({'volume_change', 'forced', 'routine', 'system_woke'}, function()
  version = version + 1
  local current = version
  util.macos('var app = Application.currentApplication(); app.includeStandardAdditions = true; JSON.stringify(app.getVolumeSettings())', function(result, code)
    if version ~= current then return end
    if code ~= 0 or type(result) ~= 'table' or type(result.outputVolume) ~= 'number'
        or type(result.outputMuted) ~= 'boolean' then
      item:set({icon={color=0xff9399b2}})
      return
    end
    local volume, muted = result.outputVolume, result.outputMuted
    local icon = (muted or volume == 0) and '󰖁' or volume >= 60 and '󰕾' or volume >= 30 and '󰖀' or '󰕿'
    item:set({icon={string=icon, color=0xffffffff}, label=(muted and 0 or volume) .. '%'})
  end)
end)
