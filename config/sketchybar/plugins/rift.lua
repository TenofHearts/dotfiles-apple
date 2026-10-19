local sbar = require('sketchybar')
local theme = require('plugins.theme')
local util = require('plugins.util')
local spacing = require('plugins.spacing')
local json = require('dkjson')
local M = {}
local items, rows, mode, controller = {}, {}, nil, nil
local screens, refreshing, pending, scheduled = nil, false, false, false
local refresh
local function name(key) return 'rift.workspace.' .. key end
local function show_mode(value)
  -- SbarLua leaves scalar JSON output as text, unlike object/array results.
  value = util.trim(value)
  if value:sub(1,1) == '"' then value = assert(json.decode(value)) end
  value = value == 'default' and 'main' or value
  mode:set({label={string=value:upper(), color=value == 'main' and theme.text or theme.mode}})
end
local function style(row)
  local item = items[row.key]
  if not item then return end
  item:set({display=row.display, drawing=row.active or row.occupied,
    icon={string=row.name, color=row.active and theme.on_accent or theme.workspace_text},
    label={drawing=row.active}, background={color=row.active and theme.active_workspace or theme.workspace}})
end
local function schedule()
  pending = true
  if scheduled then return end
  scheduled = true
  sbar.delay(0.05, function() scheduled = false; refresh() end)
end
local function render(result)
  local desired, order = {}, {}
  rows = result
  for _, row in ipairs(rows) do
    desired[row.key] = true
    if not items[row.key] then
      local uuid, index = row.uuid, row.index
      local item = sbar.add('item', name(row.key), {position='left', drawing=false,
        icon={string=row.name, font={family='Menlo', style=theme.workspace_font_style or 'Regular',
          size=12.0, typographical_width=true}, width='dynamic', align='center', padding_left=8, padding_right=8},
        label={string='●', drawing=false, font='SF Pro:Regular:8.0', color=theme.on_accent, padding_left=0, padding_right=7},
        padding_left=spacing.inside/2, padding_right=spacing.inside/2,
        background={drawing=true, height=22, color=theme.workspace, corner_radius=11}})
      item:subscribe('mouse.clicked', function()
        -- The display must be selected before switching its virtual workspace.
        sbar.exec('rift-cli execute display focus --uuid ' .. util.quote(uuid) ..
          ' && rift-cli execute workspace switch ' .. index)
      end)
      items[row.key] = item
    end
    style(row)
    order[#order+1] = util.quote(name(row.key))
  end
  for key, item in pairs(items) do
    if not desired[key] then sbar.remove(item); items[key] = nil end
  end
  local membership = table.concat(order, '\n')
  if M.membership ~= membership then
    local moves = {'sketchybar'}
    for _, item_name in ipairs(order) do moves[#moves+1] = '--move ' .. item_name .. ' before rift.mode' end
    if #moves > 1 then
      local command = table.concat(moves, ' ')
      sbar.delay(0, function() sbar.exec(command) end)
    end
    M.membership = membership
  end
end
refresh = function()
  if refreshing then pending = true; return end
  refreshing, pending = true, false
  local function finish(error_message)
    refreshing = false
    if error_message then
      mode:set({label='RIFT OFF'})
      for _, item in pairs(items) do item:set({drawing=false}) end
      io.stderr:write('rift: ', error_message, '\n')
    end
    if pending then schedule() end
  end
  local function query()
    local mapping = screens
    util.exec('rift-cli query displays', function(displays, code)
      if code ~= 0 or type(displays) ~= 'table' then finish('Cannot query displays'); return end
      local result, outstanding, failed = {}, 1, false
      local function received()
        outstanding = outstanding - 1
        if outstanding > 0 then return end
        if failed then finish('Cannot query workspaces/mode'); return end
        table.sort(result, function(a,b)
          if a.display == b.display then return a.index < b.index end
          return a.display < b.display
        end)
        render(result); finish()
      end
      for _, display in ipairs(displays) do
        if display.space and display.is_active_space then
          local screen = mapping[display.screen_id]
          if not screen then screens = nil; finish('Display topology changed'); schedule(); return end
          outstanding = outstanding + 1
          util.exec('rift-cli query workspaces --display ' .. util.quote(display.uuid), function(workspaces, workspace_code)
            if workspace_code ~= 0 or type(workspaces) ~= 'table' then failed = true
            else
              for _, workspace in ipairs(workspaces) do
                result[#result+1] = {key=display.uuid .. ':' .. workspace.index,
                  name=workspace.name, index=workspace.index, uuid=display.uuid, display=screen,
                  active=workspace.is_active, occupied=workspace.window_count > 0}
              end
            end
            received()
          end)
        end
      end
      util.exec('rift-cli query binding-mode', function(value, mode_code)
        if mode_code ~= 0 or type(value) ~= 'string' then failed = true
        else show_mode(value) end
        received()
      end)
    end)
  end
  if screens then query(); return end
  -- NSScreen order is needed only when the display topology changes.
  util.macos([[ObjC.import('AppKit'); var a=[]; var s=$.NSScreen.screens;
for(var i=0;i<s.count;i++)a.push({id:ObjC.unwrap(s.objectAtIndex(i).deviceDescription.objectForKey('NSScreenNumber')),index:i+1}); JSON.stringify(a);]], function(result, code)
    if code ~= 0 or type(result) ~= 'table' then finish('Cannot map displays'); return end
    screens = {}
    for _, screen in ipairs(result) do screens[screen.id] = screen.index end
    query()
  end)
end
function M.setup()
  mode = sbar.add('item', 'rift.mode', {position='left',
    padding_left=spacing.between-spacing.inside/2, icon={drawing=false},
    label={string='…', font='Hack Nerd Font:Bold:11.0', padding_left=0}})
  sbar.add('event', 'rift_event')
  controller = sbar.add('item', 'rift.refresh', {position='left', drawing=false, update_freq=30})
  local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
  local function ensure()
    sbar.exec('lua ' .. util.quote(config .. '/plugins/rift-stream.lua') .. ' ensure')
  end
  controller:subscribe('rift_event', function(env)
    if env.EVENT == 'binding_mode_changed' then show_mode(env.MODE); return end
    if env.EVENT == 'workspace_changed' then
      -- Immediate highlight from the stream; the coalesced query reconciles occupancy.
      for _, row in ipairs(rows) do
        if row.uuid == env.DISPLAY then row.active = row.name == env.WORKSPACE; style(row) end
      end
    end
    schedule()
  end)
  controller:subscribe({'forced', 'routine', 'system_woke', 'display_change'}, function(env)
    if env.SENDER == 'display_change' or env.SENDER == 'system_woke' then screens = nil end
    ensure(); schedule()
  end)
end
return M
