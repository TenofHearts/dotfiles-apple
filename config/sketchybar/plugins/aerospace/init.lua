local sbar = require('sketchybar')
local theme = require('plugins.theme')
local util = require('plugins.util')
local spacing = require('plugins.spacing')
local M = {}
local items, rows, occupied = {}, {}, {}
local mode, controller
local generation, refreshing, pending = 0, false, false
local refresh
local function name(workspace) return 'aerospace.workspace.' .. util.hex(workspace) end
local function style(workspace, active, monitor)
  local item = items[workspace]
  if not item then return end
  util.set(item, {display=monitor, drawing=active or occupied[workspace] or false,
    icon={color=active and theme.on_accent or theme.workspace_text},
    background={color=active and theme.active_workspace or theme.workspace}})
end
local function add(workspace)
  local item = sbar.add('item', name(workspace), {position='left', drawing=false,
    icon={string=workspace,
      font={family='Menlo', style=theme.workspace_font_style or 'Regular', size=12.0, typographical_width=true},
      width='dynamic', align='center', padding_left=8, padding_right=8},
    label={drawing=false},
    padding_left=spacing.inside/2, padding_right=spacing.inside/2,
    background={drawing=true, height=22, color=theme.workspace, corner_radius=11}})
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
      util.set(controller, {label='Unavailable'})
      -- Keep the last valid pills visible during a transient IPC failure.
      sbar.delay(2, refresh)
      return
    end
    util.set(controller, {label=''})
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
    for _, row in ipairs(rows) do order[#order+1] = name(row.workspace) end
    local membership = table.concat(order, '\n')
    if M.membership ~= membership then
      util.move_before(order, 'aerospace.mode')
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
  mode = sbar.add('item', 'aerospace.mode', {position='left',
    padding_left=spacing.between-spacing.inside/2, icon={drawing=false},
    label={string='…', font='Hack Nerd Font:Bold:11.0', padding_left=0}})
  sbar.add('event', 'aerospace_event')
  controller = sbar.add('item', 'aerospace.refresh', {position='left', drawing=false, update_freq=30})
  local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
  local function ensure()
    sbar.exec('lua ' .. util.quote(config .. '/plugins/aerospace/stream.lua') .. ' ensure')
  end
  controller:subscribe('aerospace_event', function(env)
    if env.EVENT == 'mode-changed' then
      util.set(mode, {label={string=env.MODE:upper(), color=env.MODE == 'main' and theme.text or theme.mode}})
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
