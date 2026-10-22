-- Run with: lua tests/test_sketchybar.lua
package.path = './config/sketchybar/?.lua;./config/sketchybar/?/init.lua;' .. package.path
local function equal(actual, expected, message)
  assert(actual == expected, (message or 'Mismatch') .. ': ' .. tostring(actual) .. ' ~= ' .. tostring(expected))
end
local passed = 0
local function test(name, run)
  local execute = os.execute
  local ok, error_message = xpcall(run, debug.traceback)
  os.execute = execute
  if not ok then
    io.stderr:write('FAIL: ', name, '\n', error_message, '\n')
    os.exit(1)
  end
  passed = passed + 1
  print('PASS: ' .. name)
end
local function fixture()
  for _, name in ipairs({'sketchybar', 'plugins.util', 'plugins.omniwm',
      'plugins.omniwm.state', 'plugins.wake'}) do
    package.loaded[name] = nil
  end
  local f = {now=0, timers={}, items={}, commands={}, measurements={}, queries={}, bars={}, moves={}}
  local sbar = {}
  function sbar.add(kind, name, properties)
    if kind == 'event' then return end
    local item = {name=name, properties=properties or {}, subscriptions={}}
    function item:set(delta)
      local function merge(target, values)
        for key, value in pairs(values) do
          if type(value) == 'table' then
            if type(target[key]) ~= 'table' then target[key] = {} end
            merge(target[key], value)
          else target[key] = value end
        end
      end
      merge(self.properties, delta)
    end
    function item:subscribe(events, callback)
      if type(events) == 'string' then events = {events} end
      for _, event in ipairs(events) do self.subscriptions[event] = callback end
    end
    f.items[name] = item
    return item
  end
  function sbar.delay(seconds, callback) f.timers[#f.timers+1] = {at=f.now+seconds, callback=callback} end
  function sbar.exec(command, callback)
    f.commands[#f.commands+1] = command
    if command:find('osascript', 1, true) then f.measurements[#f.measurements+1] = callback
    elseif callback then f.queries[#f.queries+1] = callback end
  end
  function sbar.bar(properties) f.bars[#f.bars+1] = properties end
  function sbar.remove(item) f.items[item.name] = nil end
  function sbar.query(name) f.committed = name end
  function f.advance(seconds)
    local until_time = f.now + seconds
    while true do
      table.sort(f.timers, function(a,b) return a.at < b.at end)
      if not f.timers[1] or f.timers[1].at > until_time then break end
      local timer = table.remove(f.timers, 1)
      f.now = timer.at; timer.callback()
    end
    f.now = until_time
  end
  function f.send(item, event, env)
    env = env or {}; env.SENDER = event
    assert(f.items[item].subscriptions[event], event)(env)
  end
  package.loaded.sketchybar = sbar
  package.loaded['plugins.theme'] = {text=1, on_accent=2, workspace_text=3, workspace=4, active_workspace=5}
  package.loaded['plugins.omniwm.windows'] = {set_workspaces=function() end}
  local util = require('plugins.util')
  util.move_before = function(names, anchor) f.moves[#f.moves+1] = {names=names, anchor=anchor} end
  function f.start()
    require('plugins.omniwm').setup()
    f.send('omniwm.refresh', 'forced'); f.advance(0.1)
  end
  function f.measured(id) table.remove(f.measurements, 1)({{screen=1, displayId=id}}, 0) end
  function f.answer(id)
    local workspaces = {}
    for i=1,2 do
      workspaces[i] = {rawName=tostring(i), id='workspace-' .. i,
        isVisible=i == 1, display={id='display:' .. id}, counts={total=0}}
    end
    table.remove(f.queries, 1)({ok=true, result={payload={workspaces=workspaces}}}, 0)
  end
  return f
end

-- Wake/display bursts rebuild once after the last notification. Normal focus
-- changes between monitors must not rebuild native bar windows.
test('wake bursts rebuild once after displays settle', function()
  local f = fixture()
  require('plugins.wake')
  f.send('wake.listener', 'display_change'); f.advance(4); equal(#f.bars, 0)
  f.send('wake.listener', 'system_woke'); f.advance(0.5)
  f.send('wake.listener', 'system_woke'); f.advance(1)
  f.send('wake.listener', 'display_change'); f.advance(2.9); equal(#f.bars, 0)
  f.advance(0.2); equal(#f.bars, 1); equal(f.bars[1].topmost, false)
end)

-- Old focus must not undo the authoritative workspace state. Wake preserves
-- pills through event churn and requests a fresh stream only once it settles.
test('stale focus and wake events preserve visible pills', function()
  local f = fixture(); f.start(); f.measured(1); f.answer(1)
  local active = f.items['omniwm.workspace.31'].properties.background.color
  f.send('omniwm.refresh', 'omniwm_event', {EVENT='focus', WORKSPACE='2'})
  equal(f.items['omniwm.workspace.31'].properties.background.color, active)
  f.send('omniwm.refresh', 'system_woke'); f.advance(1)
  f.send('omniwm.refresh', 'display_change')
  f.send('omniwm.refresh', 'omniwm_event', {EVENT='active-workspace', WORKSPACE='2'})
  f.advance(2.9)
  equal(f.items['omniwm.workspace.31'].properties.background.color, active)
  equal(#f.measurements, 0)
  f.advance(0.2); equal(#f.measurements, 1)
  equal(f.commands[#f.commands-1]:match('ensure refresh$'), 'ensure refresh')
end)

-- A display snapshot started before wake must not repopulate the cleared cache.
test('pre-wake measurements cannot restore the old display cache', function()
  local f = fixture(); f.start()
  f.send('omniwm.refresh', 'system_woke')
  f.measured(1); f.answer(1)
  f.advance(3.2); equal(#f.measurements, 1)
  f.measured(23); f.answer(23)
  equal(f.items['omniwm.workspace.31'].properties.drawing, true)
end)

-- A failed topology conversion retries with a new measurement, preserving the
-- last good pills until matching native and WM snapshots become available.
test('topology failures preserve pills and remeasure on retry', function()
  local f = fixture(); f.start(); f.measured(1); f.answer(1)
  f.send('omniwm.refresh', 'routine'); f.advance(0.1); f.answer(23)
  equal(f.items['omniwm.workspace.31'].properties.drawing, true)
  f.advance(2.1); equal(#f.measurements, 1)
  f.measured(23); f.answer(23)
  equal(f.items['omniwm.refresh'].properties.label, '')
end)

-- Move operations must flush pending item creation and finish synchronously.
test('item ordering commits creation before moving items', function()
  local f = fixture()
  package.loaded['plugins.util'] = nil
  local util = require('plugins.util')
  local order = {'anchor', 'second', 'first'}
  local function index(name)
    for i, value in ipairs(order) do if value == name then return i end end
    error('Missing item: ' .. name)
  end
  os.execute = function(command)
    equal(f.committed, 'anchor')
    for name, anchor in command:gmatch("%-%-move '(.-)' before '(.-)'") do
      table.remove(order, index(name))
      table.insert(order, index(anchor), name)
    end
    return true
  end
  util.move_before({'first', 'second'}, 'anchor')
  equal(table.concat(order, ','), 'first,second,anchor')
end)
print(('SketchyBar regression checks passed (%d scenarios)'):format(passed))
