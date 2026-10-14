local sbar = require('sketchybar')
local util = require('plugins.util')
local item = sbar.add('item', 'network', {position='right', update_freq=15, icon='󰖪', label={drawing=false}})
local version = 0
item:subscribe({'forced', 'routine', 'wifi_change', 'system_woke'}, function()
  version = version + 1
  local current = version
  -- A local route (including a VPN/virtual interface) does not prove internet access.
  -- Check the expected body as captive portals can also return HTTP 200.
  util.exec('/usr/bin/curl --silent --show-error --fail --noproxy "*" --connect-timeout 3 --max-time 5 https://captive.apple.com/hotspot-detect.html', function(result, code)
    if version ~= current then return end
    local connected = code == 0 and type(result) == 'string'
      and result:find('<BODY>Success</BODY>', 1, true) ~= nil
    item:set({icon={string=connected and '󰖩' or '󰖪', color=connected and 0xffa6e3a1 or 0xff9399b2}})
  end)
end)
