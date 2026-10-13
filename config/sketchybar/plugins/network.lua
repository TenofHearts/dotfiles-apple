local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'network', {position='right', update_freq=15, icon='󰖩'})
local busy = false
item:subscribe({'forced', 'routine', 'wifi_change', 'system_woke'}, function()
  if busy then return end
  busy = true
  util.exec('/usr/sbin/scutil --nwi', function(result, code)
    busy = false
    if code ~= 0 then item:set({label='Unavailable'}); return end
    local connected = result:find('(Reachable)', 1, true) ~= nil
    item:set({icon={string=connected and '󰖩' or '󰖪', color=connected and 0xffa6e3a1 or 0xff9399b2},
      label=connected and 'Connected' or 'Offline'})
  end)
end)
