local M = {}
function M.selected()
  local path = os.getenv('HOME') .. '/.config/window-manager/manager'
  local file = assert(io.open(path, 'r'))
  local manager = file:read('*l'); file:close()
  assert(manager == 'rift' or manager == 'aerospace', 'Invalid window manager: ' .. tostring(manager))
  return manager
end
function M.setup() require('plugins.' .. M.selected()).setup() end
return M
