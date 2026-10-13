-- Run from the repo root: lua tests/test_sketchybar.lua
package.path = 'config/sketchybar/?.lua;' .. package.path
require('runtime')
local items, commands, delays = {}, {}, {}
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
  return item
end
function mock.exec(command, callback) commands[#commands+1] = {command=command, callback=callback} end
function mock.delay(_, callback) delays[#delays+1] = callback end
function mock.remove(item) for name, value in pairs(items) do if item == value then items[name] = nil end end end
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
items.volume.events.volume_change({INFO='75'})
respond('volume settings', '5')
assert(items.volume.props.label == '75%')
items.volume.events.volume_change({INFO='0'})
assert(items.volume.props.icon == '󰖁')
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
items.network.events.forced(); respond('scutil', 'Reachability: (Reachable)')
assert(items.network.props.label == 'Connected')
items.network.events.wifi_change(); respond('scutil', 'No route')
assert(items.network.props.label == 'Offline')
require('plugins.bluetooth')
items.bluetooth.events.forced(); respond('system_profiler', {SPBluetoothDataType={{
  controller_properties={controller_state='attrib_on'}, device_connected={{Mouse={}}, {Keyboard={}}}}}})
assert(items.bluetooth.props.label == '2 connected')
print('System plugins: event ordering, volume mute, battery/charging, reachability, device counts passed')
