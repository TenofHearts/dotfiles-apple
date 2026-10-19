-- Cycle the current workspace's actual layout; direct layout shortcuts stay in sync.
local M = {}
M.layouts = {'traditional', 'bsp', 'master_stack', 'scrolling', 'stack', 'floating'}
function M.next_mode(current)
  for index, mode in ipairs(M.layouts) do
    if mode == current then return M.layouts[index % #M.layouts + 1] end
  end
  error('Unknown Rift layout: ' .. tostring(current))
end
local function main()
  local tree = os.getenv('DOTFILES_LUA_TREE') or os.getenv('HOME') .. '/.local/share/dotfiles-lua'
  package.path = tree .. '/share/lua/5.5/?.lua;' .. package.path
  local json = require('dkjson')
  local pipe = assert(io.popen('rift-cli query workspace-layout'))
  local output = pipe:read('*a')
  assert(pipe:close())
  local workspaces, _, err = json.decode(output)
  assert(type(workspaces) == 'table', err)
  for _, workspace in ipairs(workspaces) do
    if workspace.is_active then
      local index = assert(math.tointeger(workspace.index))
      local mode = M.next_mode(workspace.layout_mode)
      assert(os.execute(('rift-cli execute workspace set-layout --workspace-id %d %s >/dev/null'):format(index, mode)))
      return
    end
  end
  error('Rift has no active workspace to change')
end
if arg and arg[0] and arg[0]:match('([^/]+)$') == 'cycle-layout.lua' then main() end
return M
