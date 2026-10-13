local sbar = require('sketchybar')
local util = require('plugins.util')
local M = {}
local items, rows, occupied = {}, {}, {}
local mode, controller
local generation, refreshing, pending = 0, false, false
local refresh
local function name(workspace) return 'aerospace.workspace.' .. util.hex(workspace) end
local function style(workspace, active, monitor)
  local item = items[workspace]
  if not item then return end
  item:set({display=monitor, drawing=active or occupied[workspace] or false,
    icon={color=active and 0xff1e1e2e or 0xffcdd6f4},
    label={drawing=active}, background={color=active and 0xff89b4fa or 0x30313244}})
end
local function add(workspace)
  local item = sbar.add('item', name(workspace), {position='left', drawing=false,
    icon={string=workspace, font='SF Pro:Semibold:12.0', width=20, align='center', padding_left=5, padding_right=5},
    label={string='●', drawing=false, font='SF Pro:Regular:8.0', color=0xff1e1e2e, padding_left=0, padding_right=7},
    padding_left=3, padding_right=3,
    background={drawing=true, height=22, color=0x30313244, corner_radius=11}})
  item:subscribe('mouse.clicked', function()
    sbar.exec('aerospace workspace -- ' .. util.quote(workspace))
  end)
  items[workspace] = item
end
local function schedule()
  pending = true
  local version = generation
  sbar.delay(0.15, function()
    if version == generation then refresh() end
  end)
end
local function highlight(workspace)
  local display
  for _, row in ipairs(rows) do
    if row.workspace == workspace then display = row['monitor-appkit-nsscreen-screens-id'] end
  end
  if not display then return end
  for _, row in ipairs(rows) do
    if row['monitor-appkit-nsscreen-screens-id'] == display then
      style(row.workspace, row.workspace == workspace, display)
    end
  end
end
refresh = function()
  if refreshing then pending = true; return end
  refreshing, pending = true, false
  local version, results, remaining, failed = generation, {}, 2, false
  local function received(key, result, code)
    results[key] = result
    if code ~= 0 then failed = true end
    remaining = remaining - 1
    if remaining > 0 then return end
    refreshing = false
    if version ~= generation then schedule(); return end
    if failed or type(results.rows) ~= 'table' or type(results.occupied) ~= 'table' then
      controller:set({label='Unavailable'})
      for _, item in pairs(items) do item:set({drawing=false}) end
      sbar.delay(2, refresh)
      return
    end
    controller:set({label=''})
    rows, occupied = results.rows, {}
    for _, row in ipairs(results.occupied) do occupied[row.workspace] = true end
    local desired = {}
    for _, row in ipairs(rows) do
      local workspace = row.workspace
      desired[workspace] = true
      if not items[workspace] then add(workspace) end
      style(workspace, row['workspace-is-visible'], row['monitor-appkit-nsscreen-screens-id'])
    end
    for workspace, item in pairs(items) do
      if not desired[workspace] then sbar.remove(item); items[workspace] = nil end
    end
    -- Keep workspaces together before the mode indicator in AeroSpace's order.
    -- Reorder only permutes existing slots, so move items in one CLI batch.
    local order = {}
    for _, row in ipairs(rows) do order[#order+1] = util.quote(name(row.workspace)) end
    local membership = table.concat(order, '\n')
    if M.membership ~= membership then
      local moves = {'sketchybar'}
      for _, item_name in ipairs(order) do
        moves[#moves+1] = '--move ' .. item_name .. ' before aerospace.mode'
      end
      local command = table.concat(moves, ' ')
      sbar.delay(0, function() sbar.exec(command) end)
      M.membership = membership
    end
    if pending then schedule() end
  end
  util.exec("aerospace list-workspaces --all --format '%{workspace} %{monitor-appkit-nsscreen-screens-id} %{workspace-is-visible}' --json",
    function(result, code) received('rows', result, code) end)
  util.exec("aerospace list-workspaces --monitor all --empty no --format '%{workspace}' --json",
    function(result, code) received('occupied', result, code) end)
end
function M.setup()
  for i=1,9 do add(tostring(i)) end
  mode = sbar.add('item', 'aerospace.mode', {position='left', icon={drawing=false},
    label={string='…', font='Hack Nerd Font:Bold:11.0'}})
  sbar.add('event', 'aerospace_event')
  controller = sbar.add('item', 'aerospace.refresh', {position='left', drawing=false, update_freq=30})
  local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
  local function ensure()
    sbar.exec('lua ' .. util.quote(config .. '/plugins/aerospace-stream.lua') .. ' ensure')
  end
  controller:subscribe('aerospace_event', function(env)
    if env.EVENT == 'mode-changed' then
      mode:set({label={string=env.MODE:upper(), color=env.MODE == 'main' and 0xffffffff or 0xfffab387}})
      return
    end
    generation = generation + 1
    if env.EVENT == 'focused-workspace-changed' then highlight(env.WORKSPACE) end
    schedule()
  end)
  controller:subscribe({'forced', 'routine', 'system_woke', 'display_change'}, function(env)
    ensure()
    -- Routine refresh catches occupancy changes that have no AeroSpace event.
    generation = generation + 1
    schedule()
  end)
end
return M
