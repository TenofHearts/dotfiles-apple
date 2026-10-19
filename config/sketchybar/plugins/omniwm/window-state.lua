-- Use native Niri columns and visible split geometry for spatial icon ordering.
local M = {}
-- Recover spatial containers by cutting only through gaps shared by every
-- window. This describes the visible layout, not hidden Dwindle tab membership.
local function spatial_layout(windows)
  if #windows < 2 then return end
  for _, w in ipairs(windows) do
    local p = w.position
    if w.mode ~= 'tiling' or w.columnIndex or w.hiddenReason or w.isVisible == false
        or not p or not p.width or not p.height then return end
  end
  local function partition(members, axis)
    local sorted = {table.unpack(members)}
    local function start(w) return axis == 'x' and w.position.x or -w.position.top end
    local function finish(w)
      return start(w) + (axis == 'x' and w.position.width or w.position.height)
    end
    table.sort(sorted, function(a, b)
      if start(a) ~= start(b) then return start(a) < start(b) end
      return a.id < b.id
    end)
    local parts, part, edge = {}, {}, -math.huge
    for _, w in ipairs(sorted) do
      if #part > 0 and start(w) >= edge - 1 then
        parts[#parts+1], part, edge = part, {}, -math.huge
      end
      part[#part+1] = w
      edge = math.max(edge, finish(w))
    end
    parts[#parts+1] = part
    if #parts > 1 then return parts end
  end
  local function build(members)
    local node = {members=members}
    if #members > 1 then
      local parts = partition(members, 'x') or partition(members, 'y')
      if parts then
        node.children, node.members = {}, {}
        for _, part in ipairs(parts) do
          local child = build(part)
          node.children[#node.children+1] = child
          for _, w in ipairs(child.members) do node.members[#node.members+1] = w end
        end
      end
    end
    return node
  end
  return build(windows)
end
function M.project(channel, payload)
  if channel == 'focus' then
    local w = payload.window
    return w and {window={id=w.id, title=w.title, app=w.app, workspace=w.workspace}} or {}
  elseif channel == 'active-workspace' then
    return {workspace=payload.workspace}
  elseif channel == 'windows-changed' then
    local windows = {}
    for _, w in ipairs(payload.windows or {}) do
      local frame = w.frame
      windows[#windows+1] = {id=w.id, workspace=w.workspace, app=w.app, title=w.title,
        isVisible=w.isVisible, columnIndex=w.columnIndex, mode=w.mode, hiddenReason=w.hiddenReason,
        -- IPC uses AppKit coordinates (Y grows upwards), so top is y+height.
        position=frame and {x=math.floor(frame.x + 0.5), top=math.floor(frame.y + frame.height + 0.5),
          width=math.floor(frame.width + 0.5), height=math.floor(frame.height + 0.5)} or nil}
    end
    return {windows=windows}
  end
end
function M.visible(windows, workspace)
  local result = {}
  for _, w in ipairs(windows) do
    -- Include inactive tabs and floating windows, not just visible tiles.
    if w.workspace and workspace and w.workspace.id == workspace.id then result[#result+1] = w end
  end
  return result
end
function M.ordered(windows, positions)
  for _, w in ipairs(windows) do
    local cached = positions[w.id]
    if cached and cached.workspace ~= (w.workspace or {}).id then positions[w.id] = nil end
    if w.position and w.isVisible ~= false and not w.hiddenReason then
      positions[w.id] = {x=w.position.x, top=w.position.top, workspace=(w.workspace or {}).id}
    end
  end
  local tree = spatial_layout(windows)
  if tree and tree.children then
    local ordered = {}
    local function visit(node)
      if node.children then
        for _, child in ipairs(node.children) do visit(child) end
      else
        for _, w in ipairs(node.members) do ordered[#ordered+1] = w end
      end
    end
    visit(tree)
    return ordered
  end
  local units, by_key = {}, {}
  for index, w in ipairs(windows) do
    local key = w.columnIndex and w.mode == 'tiling' and 'column:' .. w.columnIndex or 'window:' .. w.id
    local unit = by_key[key]
    if not unit then
      unit = {members={}, x=math.huge, top=-math.huge, index=index}
      units[#units+1], by_key[key] = unit, unit
    end
    local position = positions[w.id]
    if position then unit.x = math.min(unit.x, position.x); unit.top = math.max(unit.top, position.top) end
    unit.members[#unit.members+1] = {window=w, position=position, index=index}
  end
  table.sort(units, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.top ~= b.top then return a.top > b.top end
    return a.index < b.index
  end)
  local ordered = {}
  for _, unit in ipairs(units) do
    table.sort(unit.members, function(a, b)
      local ay, by = a.position and a.position.top or -math.huge, b.position and b.position.top or -math.huge
      if ay ~= by then return ay > by end
      return a.index < b.index
    end)
    for _, member in ipairs(unit.members) do ordered[#ordered+1] = member.window end
  end
  return ordered
end
return M
