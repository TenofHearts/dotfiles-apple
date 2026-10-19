local sbar = require('sketchybar')
local theme = require('plugins.theme')
local util = require('plugins.util')
local spacing = require('plugins.spacing')
local M = {}
local items, rows, occupied = {}, {}, {}
local mode, controller
local generation, refreshing, pending = 0, false, false
local refresh
local screens_cache
local function name(workspace) return 'omniwm.workspace.' .. util.hex(workspace) end
local function style(workspace, active, monitor)
  local item = items[workspace]
  if not item then return end
  item:set({display=monitor, drawing=active or occupied[workspace] or false,
    icon={color=active and theme.on_accent or theme.workspace_text},
    label={drawing=active}, background={color=active and theme.active_workspace or theme.workspace}})
end
local function add(workspace)
  local item = sbar.add('item', name(workspace), {position='left', drawing=false,
    icon={string=workspace,
      font={family='Menlo', style=theme.workspace_font_style or 'Regular', size=12.0, typographical_width=true},
      width='dynamic', align='center', padding_left=8, padding_right=8},
    label={string='●', drawing=false, font='SF Pro:Regular:8.0', color=theme.on_accent, padding_left=0, padding_right=7},
    padding_left=spacing.inside/2, padding_right=spacing.inside/2,
    background={drawing=true, height=22, color=theme.workspace, corner_radius=11}})
  item:subscribe('mouse.clicked', function()
    sbar.exec(require('plugins.omniwm-state').cli .. ' workspace focus-name ' .. util.quote(workspace))
  end)
  items[workspace] = item
end
local function schedule()
  pending = true
  local version = generation
  sbar.delay(0.05, function()
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
    -- Keep workspaces together before the mode indicator in OmniWM's order.
    -- Reorder only permutes existing slots, so move items in one CLI batch.
    local order = {}
    for _, row in ipairs(rows) do order[#order+1] = util.quote(name(row.workspace)) end
    local membership = table.concat(order, '\n')
    if M.membership ~= membership then
      local moves = {'sketchybar'}
      for _, item_name in ipairs(order) do
        moves[#moves+1] = '--move ' .. item_name .. ' before omniwm.mode'
      end
      local command = table.concat(moves, ' ')
      sbar.delay(0, function() sbar.exec(command) end)
      M.membership = membership
    end
    if pending then schedule() end
  end
  local state = require('plugins.omniwm-state')
  local function query(screens, code)
    if code ~= 0 then received('rows', nil, code); received('occupied', nil, code); return end
    screens_cache = screens
    util.exec(state.cli .. ' query workspaces --json', function(result, query_code)
      local ok, workspaces, filled = pcall(state.rows, result, screens)
      received('rows', ok and workspaces or nil, ok and query_code or 1)
      received('occupied', ok and filled or nil, ok and query_code or 1)
    end)
  end
  if screens_cache then query(screens_cache, 0)
  else util.macos(state.screens, query) end
end
function M.setup()
  for i=1,9 do add(tostring(i)) end
  mode = sbar.add('item', 'omniwm.mode', {position='left',
    padding_left=spacing.between-spacing.inside/2, icon={drawing=false},
    label={string='…', font='Hack Nerd Font:Bold:11.0', padding_left=0}})
  sbar.add('event', 'omniwm_event')
  controller = sbar.add('item', 'omniwm.refresh', {position='left', drawing=false, update_freq=30})
  local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
  local function refresh_mode()
    local state_path = (os.getenv('XDG_STATE_HOME') or os.getenv('HOME') .. '/.local/state') .. '/dotfiles/wm-mode'
    local file = io.open(state_path, 'r')
    local current = file and file:read('*l') or 'main'
    if file then file:close() end
    mode:set({label={string=current:upper(), color=current == 'main' and theme.text or theme.mode}})
  end
  local function ensure()
    refresh_mode()
    sbar.exec('lua ' .. util.quote(config .. '/plugins/omniwm-stream.lua') .. ' ensure')
  end
  controller:subscribe('omniwm_event', function(env)
    if env.EVENT == 'mode-changed' then
      refresh_mode() -- Read authoritative state; callback notifications may arrive late.
      return
    end
    generation = generation + 1
    if env.WORKSPACE and env.WORKSPACE ~= '' then highlight(env.WORKSPACE) end
    schedule()
  end)
  controller:subscribe({'forced', 'routine', 'system_woke', 'display_change'}, function(env)
    if env.SENDER ~= 'routine' then screens_cache = nil end
    ensure()
    -- Routine refresh catches occupancy changes that have no OmniWM event.
    generation = generation + 1
    schedule()
  end)
end
return M
