-- Run from the repo root: lua tests/test_sketchybar.lua
package.path = 'config/sketchybar/?.lua;' .. package.path
require('runtime')
local items, commands, delays = {}, {}, {}
local item_order = {}
local function merge(to, from)
  for key, value in pairs(from) do
    if type(value) == 'table' then
      if type(to[key]) ~= 'table' then to[key] = {} end
      merge(to[key], value)
    else to[key] = value end
  end
end
local mock = {}
function mock.add(kind, name, props)
  if kind == 'event' then return end
  local item = {props=props or {}, events={}}
  function item:set(properties) merge(self.props, properties) end
  function item:subscribe(events, callback)
    if type(events) == 'string' then events = {events} end
    for _, event in ipairs(events) do self.events[event] = callback end
  end
  items[name] = item
  item_order[#item_order+1] = name
  return item
end
function mock.exec(command, callback)
  commands[#commands+1] = {command=command, callback=callback}
  -- Model CLI ordering: reorder only permutes the named slots; move inserts.
  if command:match('^sketchybar %-%-reorder ') then
    local order, selected = {}, {}
    for name in command:gsub("'", ''):gmatch('%S+') do
      if items[name] then order[#order+1] = name; selected[name] = true end
    end
    local next_index = 1
    for i, name in ipairs(item_order) do
      if selected[name] then item_order[i] = order[next_index]; next_index = next_index + 1 end
    end
  end
  for name, anchor in command:gmatch("%-%-move '([^']+)' before (%S+)") do
    for i, existing in ipairs(item_order) do
      if existing == name then table.remove(item_order, i); break end
    end
    for i, existing in ipairs(item_order) do
      if existing == anchor then table.insert(item_order, i, name); break end
    end
  end
end
function mock.delay(_, callback) delays[#delays+1] = callback end
function mock.remove(item)
  for name, value in pairs(items) do
    if item == value then
      items[name] = nil
      for i, existing in ipairs(item_order) do
        if existing == name then table.remove(item_order, i); break end
      end
    end
  end
end
function mock.bar() end
package.loaded.sketchybar = mock
local function flush_delays()
  local current = delays; delays = {}
  for _, callback in ipairs(current) do callback() end
end
local function respond(pattern, result, code)
  for i, command in ipairs(commands) do
    if command.callback and command.command:find(pattern, 1, true) then
      table.remove(commands, i); command.callback(result, code or 0); return
    end
  end
  error('No pending command for ' .. pattern)
end
local layout = require('plugins.display')
local props, gaps = layout.plan({{screen=1, notch=true, inset=32, height=33},
  {screen=2, notch=false, inset=0, height=30}},
  {{['monitor-id']=2, ['monitor-appkit-nsscreen-screens-id']=1},
   {['monitor-id']=1, ['monitor-appkit-nsscreen-screens-id']=2}})
assert(props.height == 30 and props.notch_display_height == 33)
assert(gaps:find('monitor."1" = 35', 1, true) and gaps:find('monitor."2" = 6', 1, true))
props, gaps = layout.plan({{screen=1, notch=false, inset=0, height=30},
  {screen=2, notch=false, inset=24, height=24}},
  {{['monitor-id']=1, ['monitor-appkit-nsscreen-screens-id']=1},
   {['monitor-id']=2, ['monitor-appkit-nsscreen-screens-id']=2}})
assert(props.height == 24 and gaps:find('monitor."1" = 29', 1, true) and gaps:find('monitor."2" = 5', 1, true))
assert(not pcall(layout.plan, {{screen=1, notch=false, inset=0}}, {}))
assert(not pcall(layout.plan, {{screen=1, notch=false, inset=0, height=30}}, {}))
print('Display geometry: mixed monitors, ordering, smallest menu, incomplete topology passed')
require('plugins.aerospace').setup()
require('plugins.front_app')
local control = items['aerospace.refresh']
local function snapshot(active)
  return {{workspace='1', ['monitor-appkit-nsscreen-screens-id']=1, ['workspace-is-visible']=active=='1'},
    {workspace='2', ['monitor-appkit-nsscreen-screens-id']=1, ['workspace-is-visible']=active=='2'},
    {workspace='3', ['monitor-appkit-nsscreen-screens-id']=2, ['workspace-is-visible']=true}}
end
control.events.forced({SENDER='forced'}); flush_delays()
respond('--all', snapshot('1')); respond('--empty no', {{workspace='1'}})
assert(items['aerospace.workspace.31'].props.background.color == 0xff89b4fa)
assert(not items['aerospace.workspace.32'].props.drawing)
control.events.aerospace_event({EVENT='focused-workspace-changed', WORKSPACE='2'})
assert(items['aerospace.workspace.32'].props.background.color == 0xff89b4fa)
assert(items['aerospace.workspace.33'].props.background.color == 0xff89b4fa)
flush_delays() -- Start a snapshot for workspace 2.
control.events.aerospace_event({EVENT='focused-workspace-changed', WORKSPACE='1'})
respond('--all', snapshot('2')); respond('--empty no', {{workspace='1'}})
assert(items['aerospace.workspace.31'].props.background.color == 0xff89b4fa)
flush_delays(); respond('--all', snapshot('1')); respond('--empty no', {{workspace='1'}})
control.events.aerospace_event({EVENT='mode-changed', MODE='move'})
assert(items['aerospace.mode'].props.label.string == 'MOVE')
print('AeroSpace: occupancy, two-monitor visibility, mode events, stale snapshot rejection passed')
require('plugins.volume')
items.volume.events.forced()
items.volume.events.volume_change({INFO='50'})
respond('getVolumeSettings', {outputVolume=5, outputMuted=false})
respond('getVolumeSettings', {outputVolume=50, outputMuted=true})
assert(items.volume.props.label == '0%' and items.volume.props.icon.string == '󰖁')
items.volume.events.routine()
respond('getVolumeSettings', {outputVolume=75, outputMuted=false})
assert(items.volume.props.label == '75%')
items.volume.events.volume_change({INFO='0'})
respond('getVolumeSettings', {outputVolume=0, outputMuted=false})
assert(items.volume.props.icon.string == '󰖁')
items.volume.events.routine()
respond('getVolumeSettings', '', 1)
assert(items.volume.props.label == '0%' and items.volume.props.icon.color == 0xff9399b2)
require('plugins.front_app')
items.front_app.events.forced()
items.front_app.events.front_app_switched({INFO='New app'})
respond('frontmostApplication', 'Old app')
assert(items.front_app.props.label == 'New app')
require('plugins.battery')
items.battery.events.forced(); respond('pmset', "Now drawing from 'Battery Power'\n 29%; discharging")
assert(items.battery.props.icon == '' and items.battery.props.label == '29%')
items.battery.events.system_woke(); respond('pmset', "Now drawing from 'AC Power'\n 96%; charging")
assert(items.battery.props.icon == '')
require('plugins.network')
items.network.events.forced(); respond('networksetup', 'wifi\n')
assert(items.network.props.icon.string == '󰖩' and items.network.props.label.drawing == false)
items.network.events.network_change({SENDER="network_change"})
items.network.events.wifi_change()
respond('networksetup', 'wifi\n')
respond('networksetup', '')
assert(items.network.props.icon.string == '󰖪' and items.network.props.label.drawing == false)
items.network.events.network_change({SENDER="network_change"}); respond('networksetup', 'utun4\nfeth1257\n')
assert(items.network.props.icon.string == '󰖪' and items.network.props.label.drawing == false)
items.network.events.network_change({SENDER="network_change"}); respond('networksetup', 'ethernet\nwifi\n')
assert(items.network.props.icon.string == '󰈀')
items.network.events.network_change({SENDER="network_change"}); respond('networksetup', '', 1)
assert(items.network.props.icon.string == '󰖪')
require('plugins.bluetooth')
items.bluetooth.events.forced(); respond('system_profiler', {SPBluetoothDataType={{
  controller_properties={controller_state='attrib_on'}, device_connected={{Mouse={}}, {Keyboard={}}}}}})
assert(items.bluetooth.props.label == '2' and items.bluetooth.props.icon.string == '')
items.bluetooth.events.routine(); respond('system_profiler', {SPBluetoothDataType={{
  controller_properties={controller_state='attrib_on'}, device_not_connected={{Mouse={}}}}}})
assert(items.bluetooth.props.label == '0' and items.bluetooth.props.icon.string == '')
items.bluetooth.events.routine(); respond('system_profiler', {SPBluetoothDataType={{
  controller_properties={controller_state='attrib_off'}, device_connected={{Mouse={}}}}}})
assert(items.bluetooth.props.label == '0' and items.bluetooth.props.icon.string == '󰂲')
items.bluetooth.events.routine(); respond('system_profiler', '', 1)
assert(items.bluetooth.props.label == '0' and items.bluetooth.props.icon.color == 0xff9399b2)
items.bluetooth.events.routine(); respond('system_profiler', {SPBluetoothDataType={{}}})
assert(items.bluetooth.props.label == '0' and items.bluetooth.props.icon.string == '󰂲')

print('System plugins: event ordering, volume mute, battery/charging, reachability, device counts passed')

local function check_order(workspaces)
  control.events.routine({SENDER='routine'}); flush_delays()
  local rows = {}
  local expected = {}
  for _, workspace in ipairs(workspaces) do
    rows[#rows+1] = {workspace=workspace, ['monitor-appkit-nsscreen-screens-id']=1,
      ['workspace-is-visible']=true}
    expected[#expected+1] = 'aerospace.workspace.' .. require('plugins.util').hex(workspace)
  end
  respond('--all', rows); respond('--empty no', rows); flush_delays()
  expected[#expected+1] = 'aerospace.mode'
  expected[#expected+1] = 'front_app'
  local actual = {}
  for _, name in ipairs(item_order) do
    if name:match('^aerospace%.workspace%.') or name == 'aerospace.mode' or name == 'front_app' then
      actual[#actual+1] = name
    end
  end
  assert(table.concat(actual, ',') == table.concat(expected, ','), table.concat(actual, ','))
end
check_order({'1', '2', '3', 'A'})
check_order({'1', '2', '3', 'A', 'B'})
check_order({'1', '2', '3', 'B'})
check_order({'1', '2', '3', 'A', 'B'})
print('AeroSpace ordering: workspace addition, removal and recreation preserve mode/front-app order passed')
