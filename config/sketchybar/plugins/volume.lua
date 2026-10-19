local sbar = require('sketchybar')
local theme = require('plugins.theme')
local util = require('plugins.util')
local item = sbar.add('item', 'volume', {position='right', update_freq=0, label='0%'})
-- SketchyBar's CoreAudio listener includes mute and output-device changes;
-- INFO is the effective level (zero while muted), already rounded to percent.
item:subscribe('volume_change', function(env)
  local volume = tonumber(env.INFO)
  if not volume then return end
  local icon = volume == 0 and '󰖁' or volume >= 60 and '󰕾' or volume >= 30 and '󰖀' or '󰕿'
  util.set(item, {icon={string=icon, color=theme.text}, label=volume .. '%'})
end)
item:subscribe({'forced', 'system_woke'}, function() sbar.trigger('volume_change') end)
