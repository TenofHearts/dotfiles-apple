local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'bluetooth', {position='right', update_freq=15, icon=''})
local busy = false
item:subscribe({'forced', 'routine', 'system_woke'}, function()
  if busy then return end
  busy = true
  util.exec('/usr/sbin/system_profiler SPBluetoothDataType -json', function(result, code)
    busy = false
    if code ~= 0 or type(result) ~= 'table' then item:set({label='Unavailable'}); return end
    local controller = (result.SPBluetoothDataType or {})[1] or {}
    local state = (controller.controller_properties or {}).controller_state
    local count = 0
    for _, group in ipairs(controller.device_connected or {}) do
      for _ in pairs(group) do count = count + 1 end
    end
    local label = state == 'attrib_on' and (count > 0 and count .. ' connected' or 'On') or
      state == 'attrib_off' and 'Off' or 'Unknown'
    item:set({label=label, icon={color=state == 'attrib_on' and 0xff89b4fa or 0xff9399b2}})
  end)
end)
