-- Match AeroSpace join-with: the new group is perpendicular to the join direction.
-- Native Rift joins use the direction's own axis, so a plain native join looks flat.
local M = {}
local function same_window(a, b)
  return a and b and a.pid == b.pid and a.idx == b.idx
end
local function parent_of(node, window, parent)
  if same_window(node.window_id, window) then return parent end
  for _, child in ipairs(node.children or {}) do
    local found = parent_of(child, window, node)
    if found then return found end
  end
end
local function topology(node)
  local parts = {tostring(node.node_id), node.layout_kind or 'window'}
  for _, child in ipairs(node.children or {}) do parts[#parts+1] = topology(child) end
  return '(' .. table.concat(parts, ':') .. ')'
end
function M.should_rotate(before, after, direction)
  if before.mode ~= 'traditional' or after.mode ~= 'traditional' then return false end
  local window = before.focused_window
  if not same_window(window, after.focused_window) then return false end
  -- A boundary/no-op join reports success too: never rotate its unchanged parent.
  if topology(before.container_tree) == topology(after.container_tree) then return false end
  local parent = parent_of(after.container_tree, window)
  local parallel = (direction == 'left' or direction == 'right') and 'horizontal' or 'vertical'
  return parent and parent.layout_kind == parallel or false
end
function M.join(direction, query, execute)
  assert(({left=true,down=true,up=true,right=true})[direction], 'Invalid join direction')
  -- Leave the one-shot mode before doing IPC work, including for boundary/no-op joins.
  execute('binding-mode', 'move')
  local before = query()
  if before.mode ~= 'traditional' or not before.focused_window then return end
  execute('layout', 'join-window', direction)
  local after = query()
  if M.should_rotate(before, after, direction) then execute('layout', 'toggle-orientation') end
end
local function main()
  local home = assert(os.getenv('HOME'))
  local tree = os.getenv('DOTFILES_LUA_TREE') or home .. '/.local/share/dotfiles-lua'
  package.path = tree .. '/share/lua/5.5/?.lua;' .. package.path
  package.cpath = tree .. '/lib/lua/5.5/?.so;' .. package.cpath
  local json = require('dkjson')
  local function execute(...)
    local arguments = {...}
    for _, argument in ipairs(arguments) do
      assert(argument:match('^[a-z%-]+$'), 'Invalid Rift argument')
    end
    assert(os.execute('rift-cli execute ' .. table.concat(arguments, ' ') .. ' >/dev/null'))
  end
  local function query()
    local pipe = assert(io.popen('rift-cli query layout'))
    local output = pipe:read('*a')
    assert(pipe:close())
    local value, _, err = json.decode(output)
    assert(value, err)
    return value
  end
  M.join(arg[1], query, execute)
end
-- Loading with dofile in unit tests exposes only the pure decision logic.
if arg and arg[0] and arg[0]:match('([^/]+)$') == 'join.lua' then main() end
return M
