local sbar = require('sketchybar')
local theme = require('plugins.theme')
local util = require('plugins.util')
local item = sbar.add('item', 'bluetooth', {position='right', update_freq=15, icon='', label='0'})
local busy = false
item:subscribe({'forced', 'routine', 'system_woke'}, function()
  if busy then return end
  busy = true
  util.exec('/usr/sbin/system_profiler SPBluetoothDataType -json', function(result, code)
    busy = false
    if code ~= 0 or type(result) ~= 'table' then
      item:set({label='0', icon={string='󰂲', color=theme.muted}}); return
    end
    local controller = (result.SPBluetoothDataType or {})[1] or {}
    local state = (controller.controller_properties or {}).controller_state
    local count = 0
    for _, group in ipairs(controller.device_connected or {}) do
      for _ in pairs(group) do count = count + 1 end
    end
    local enabled = state == 'attrib_on'
    item:set({label=tostring(enabled and count or 0),
      icon={string=enabled and '' or '󰂲', color=enabled and theme.accent or theme.muted}})
  end)
end)
