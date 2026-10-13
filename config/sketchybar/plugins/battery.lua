local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'battery', {position='right', update_freq=120})
local busy = false
item:subscribe({'forced', 'routine', 'system_woke', 'power_source_change'}, function()
  if busy then return end
  busy = true
  util.exec('/usr/bin/pmset -g batt', function(result, code)
    busy = false
    if code ~= 0 then item:set({label='Unavailable'}); return end
    local percentage = tonumber(result:match('(%d+)%%'))
    if not percentage then item:set({drawing=false}); return end
    local icon = percentage >= 90 and '' or percentage >= 60 and '' or
      percentage >= 30 and '' or percentage >= 10 and '' or ''
    if result:find('AC Power', 1, true) then icon = '' end
    item:set({drawing=true, icon=icon, label=percentage .. '%'})
  end)
end)
