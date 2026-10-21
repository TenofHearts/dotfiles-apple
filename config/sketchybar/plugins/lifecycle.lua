-- Helpers survive bar reloads, but not a stopped daemon or deselected backend.
local uv, lfs = require('luv'), require('lfs')
local M = {}
function M.directory(name)
  local root = os.getenv('XDG_STATE_HOME') or os.getenv('HOME') .. '/.local/state'
  local directory = root .. '/dotfiles/sketchybar/helpers/' .. name
  local path = ''
  for part in directory:gmatch('[^/]+') do
    path = path .. '/' .. part
    local ok, err = uv.fs_mkdir(path, 448)
    assert(ok or uv.fs_stat(path), err)
  end
  return directory
end
function M.guard(directory, backend, shutdown)
  local lock_path = directory .. '/stream.lock'
  local lock = assert(io.open(lock_path, 'a'))
  if not lfs.lock(lock, 'w') then lock:close(); return end
  local inode = assert(uv.fs_stat(lock_path)).ino
  local pid_path = directory .. '/stream.pid'
  local file = assert(io.open(pid_path, 'w'))
  file:write(('%d'):format(uv.os_getpid())); file:close()
  local handles, stopped = {}, false
  local function stop()
    if stopped then return end
    stopped = true
    for _, handle in ipairs(handles) do handle:stop(); handle:close() end
    shutdown()
  end
  local config = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'
  local function selected()
    if not backend then return true end
    local selection = io.open(config .. '/wm/backend', 'r')
    local current = selection and selection:read('*l') or 'aerospace'
    if selection then selection:close() end
    return current == backend
  end
  for _, name in ipairs({'sigterm', 'sigint'}) do
    local signal = uv.new_signal()
    signal:start(name, stop); handles[#handles+1] = signal
  end
  local daemon = tonumber(os.getenv('DOTFILES_SBAR_DAEMON_PID'))
  local timer = uv.new_timer()
  timer:start(5000, 5000, function()
    local current = uv.fs_stat(lock_path)
    if not current or current.ino ~= inode or not selected()
        or (daemon and not uv.kill(daemon, 0)) then stop() end
  end)
  handles[#handles+1] = timer
  if backend then
    local watcher = uv.new_fs_event()
    local ok = watcher:start(config .. '/wm', {}, function() if not selected() then stop() end end)
    if ok then handles[#handles+1] = watcher else watcher:close() end
  end
  return {
    stop=stop,
    selected=selected,
    release=function()
      -- Leave the lock pathname intact. Only its owner may remove its PID file.
      local current = uv.fs_stat(lock_path)
      if current and current.ino == inode then uv.fs_unlink(pid_path) end
      lock:close()
    end,
  }
end
return M
