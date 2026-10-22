local sbar = require('sketchybar')
local json = require('dkjson')
local util = require('plugins.util')
local theme = require('plugins.theme')
local state = require('plugins.omniwm.window-state')
local title = sbar.add('item', 'front_app', {position='left',
  icon={drawing=false}, label={string='', max_chars=28, padding_left=0}})
sbar.add('item', 'omniwm.windows.end', {position='left', drawing=false, width=0})
local windows, workspace, focused, fallback = {}, nil, nil, ''
local positions, groups = {}, {}
local limit = 6
local icon_width = 20
local function group(display)
  if groups[display] then return groups[display] end
  local prefix = 'omniwm.windows.d' .. display
  local g = {display=display, prefix=prefix, items={}, names={}, serial=0, edges={}}
  for _, edge in ipairs({'start', 'stop'}) do
    g.edges[edge] = sbar.add('item', prefix .. '.' .. edge, {position='left', display=display, drawing=false,
      width=3, padding_left=0, padding_right=0, icon={drawing=false}, label={drawing=false},
      background={drawing=false}})
  end
  groups[display] = g
  return g
end
-- SbarLua truncates long names, so keep native window IDs out of item names.
local function name(g, id)
  if not g.names[id] then
    g.serial = g.serial + 1
    g.names[id] = g.prefix .. '.w' .. g.serial
  end
  return g.names[id]
end
local function remove(item)
  if item.detail then sbar.remove(item.detail) end
  sbar.remove(item.icon)
end
local function add(g, w, inline_item)
  local item_name, app = name(g, w.id), w.app or {}
  local item = sbar.add('item', item_name, {position=inline_item and 'left' or 'popup.' .. g.prefix .. '.overflow', display=g.display,
    width=inline_item and icon_width or 'dynamic', padding_left=0, padding_right=0,
    icon={drawing=false}, label={drawing=not inline_item, max_chars=48, padding_left=30, padding_right=8},
    background={drawing=true, color=0x00000000, border_width=0, height=20,
      image={string='app.' .. (app.bundleId or app.name or ''), scale=0.5625,
        padding_left=inline_item and 1 or 7, padding_right=inline_item and 1 or 7}},
    popup={align='left', background={color=theme.bar, corner_radius=6}}})
  local detail
  if inline_item then
    detail = sbar.add('item', item_name .. '.title', {position='popup.' .. item_name,
      icon={drawing=false}, label={max_chars=60, padding_left=8, padding_right=8}})
    item:subscribe('mouse.entered', function() item:set({popup={drawing=true}}) end)
    item:subscribe('mouse.exited', function() item:set({popup={drawing=false}}) end)
  end
  return {icon=item, detail=detail, inline=inline_item}
end
local function render_group(g)
  local items, pill, edges = g.items, g.pill, g.edges
  local current = state.ordered(state.visible(windows, g.workspace), positions)
  local ids = {}
  for _, w in ipairs(current) do ids[#ids+1] = w.id end
  local membership = table.concat(ids, '\n')
  if g.signature ~= membership then
    if pill then sbar.remove(pill); pill = nil end
    local desired = {}
    for index, w in ipairs(current) do desired[w.id] = index <= limit and 'inline' or 'popup' end
    if #current > limit then desired.overflow = 'overflow' end
    for id, item in pairs(items) do
      if not desired[id] or (id ~= 'overflow' and item.inline ~= (desired[id] == 'inline')) then
        remove(item); items[id] = nil
      end
    end
    local order = {}
    if #current > limit and not items.overflow then
      local overflow_name = g.prefix .. '.overflow'
      local overflow = sbar.add('item', overflow_name, {position='left', display=g.display, icon={drawing=false},
        padding_left=0, padding_right=0,
        label={padding_left=4, padding_right=4},
        popup={align='left', background={color=theme.bar, corner_radius=6, border_width=1, border_color=theme.muted}}})
      overflow:subscribe('mouse.clicked', function() overflow:set({popup={drawing='toggle'}}) end)
      overflow:subscribe('mouse.exited.global', function() overflow:set({popup={drawing=false}}) end)
      items.overflow = {icon=overflow}
    end
    if items.overflow then util.set(items.overflow.icon, {label='+' .. (#current-limit)}) end
    for index, w in ipairs(current) do
      local item_name = name(g, w.id)
      local inline_item = index <= limit
      if not items[w.id] then items[w.id] = add(g, w, inline_item) end
      if inline_item then
        order[#order+1] = item_name
      end
    end
    if items.overflow then order[#order+1] = g.prefix .. '.overflow' end
    for _, edge in pairs(edges) do util.set(edge, {drawing=#order > 0}) end
    if #order > 0 then
      local outer_members = {g.prefix .. '.start', table.unpack(order)}
      outer_members[#outer_members+1] = g.prefix .. '.stop'
      pill = sbar.add('bracket', g.prefix .. '.pill', outer_members,
        {padding_left=0, padding_right=0,
          background={drawing=true, color=theme.workspace, corner_radius=11, height=22,
            border_width=0}})
    end
    if #order > 0 then
      table.insert(order, 1, g.prefix .. '.start')
      order[#order+1] = g.prefix .. '.stop'
    end
    util.move_before(order, 'omniwm.windows.end')
    g.signature = membership
    g.pill = pill
  end
  for _, w in ipairs(current) do
    local caption = ((w.app or {}).name or 'Window') .. ' — ' .. (w.title or '')
    util.set(items[w.id].icon, {label={string=caption, color=theme.text}})
    if items[w.id].detail then util.set(items[w.id].detail, {label=caption}) end
  end
end
local function render()
  local caption = fallback
  if focused and focused.workspace and workspace and focused.workspace.id == workspace.id then
    caption = focused.title and focused.title ~= '' and focused.title or (focused.app or {}).name or fallback
  end
  util.set(title, {label=caption})
  for _, g in pairs(groups) do render_group(g) end
end
local function set_workspaces(rows)
  local active = {}
  for _, row in ipairs(rows) do
    if row['workspace-is-visible'] then
      local display = row['monitor-appkit-nsscreen-screens-id']
      local g = group(display)
      g.workspace = {id=row.id}
      active[display] = true
    end
  end
  for display, g in pairs(groups) do
    if not active[display] then
      if g.pill then sbar.remove(g.pill) end
      for _, item in pairs(g.items) do remove(item) end
      for _, edge in pairs(g.edges) do sbar.remove(edge) end
      groups[display] = nil
    end
  end
  render()
end
sbar.add('event', 'omniwm_windows')
local listener = sbar.add('item', 'omniwm.windows.listener', {drawing=false})
listener:subscribe('omniwm_windows', function(env)
  -- SbarLua decodes JSON environment values before invoking callbacks.
  local payload = env.DATA
  if type(payload) == 'string' then payload = json.decode(payload) end
  if type(payload) ~= 'table' then return end
  if env.EVENT == 'focus' then
    focused = payload.window
  elseif env.EVENT == 'windows-changed' then
    windows = payload.windows or {}
    local live = {}
    for _, w in ipairs(windows) do live[w.id] = true end
    for id in pairs(positions) do if not live[id] then positions[id] = nil end end
    for _, g in pairs(groups) do
      for id in pairs(g.names) do if not live[id] then g.names[id] = nil end end
    end
  elseif env.EVENT == 'active-workspace' then
    workspace = payload.workspace
  else
    return
  end
  render()
end)
title:subscribe('front_app_switched', function(env)
  fallback = env.INFO or ''
  -- The focus channel supplies the managed title, including same-app switches.
  if not focused then render() end
end)
return {render=render, set_workspaces=set_workspaces}
