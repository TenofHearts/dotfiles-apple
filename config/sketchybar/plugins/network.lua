local sbar = require('sketchybar')
local util = require('plugins.util')
sbar.add('event', 'network_change')
local item = sbar.add('item', 'network', {position='right', update_freq=0, icon='󰖪', label={drawing=false}})
local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
local function ensure_listener()
  sbar.exec('lua ' .. util.quote(config .. '/plugins/network-stream.lua') .. ' ensure')
end
local version = 0
-- Use hardware ports and their link status, never routes or DNS. This excludes
-- Clash's utun interfaces and other virtual interfaces such as feth/bridge.
local command = [[/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '
/^Hardware Port:/ { wifi = ($0 ~ /Wi-Fi|AirPort/); wired = ($0 ~ /Ethernet|Thunderbolt [0-9]/) }
/^Device:/ && (wifi || wired) && $2 ~ /^en[0-9]+$/ { print $2, (wifi ? "wifi" : "ethernet") }
' | while read -r device kind; do
  if /sbin/ifconfig "$device" | /usr/bin/awk '$1 == "status:" && $2 == "active" { active = 1 } END { exit !active }'; then
    printf '%s\n' "$kind"
  fi
done]]
item:subscribe({'forced', 'network_change', 'wifi_change', 'system_woke'}, function(env)
  if not env or env.SENDER == 'forced' or env.SENDER == 'system_woke' then ensure_listener() end
  version = version + 1
  local current = version
  util.exec(command, function(result, code)
    if version ~= current then return end
    local wifi, ethernet = false, false
    if code == 0 and type(result) == 'string' then
      for kind in result:gmatch('%S+') do
        wifi = wifi or kind == 'wifi'
        ethernet = ethernet or kind == 'ethernet'
      end
    end
    local connected = wifi or ethernet
    item:set({icon={string=ethernet and '󰈀' or wifi and '󰖩' or '󰖪',
      color=connected and 0xffa6e3a1 or 0xff9399b2}})
  end)
end)
ensure_listener()
