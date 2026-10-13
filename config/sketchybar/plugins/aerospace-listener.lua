-- Persistent workspace listener using LuaJIT and luv.
local uv = require('luv')
local directory = arg[0]:match('^(.*)/') or '.'
package.path = directory .. '/vendor/?.lua;' .. package.path
local json = require('json')
local ffi = require('ffi')
ffi.cdef[[int getuid(void); int open(const char *, int, ...); int flock(int, int);]]
local state = '/tmp/sketchybar-aerospace-lua-' .. tonumber(ffi.C.getuid())
local socket_path = state .. '/notify.sock'
local function write_file(path, value)
  local file = assert(io.open(path, 'w')); file:write(value); file:close()
end
if arg[1] == 'ensure' then
  local client = uv.new_pipe(false)
  client:connect(socket_path, function(err)
    if not err then
      client:write(os.getenv('SENDER') == 'routine' and 'ping' or 'refresh', function()
        client:close()
      end)
    else
      client:close()
      uv.fs_mkdir(state, 448) -- 0700; existing directories are harmless.
      local log = assert(uv.fs_open(state .. '/listener.log', 'w', 384))
      local process = assert(uv.spawn(uv.exepath(), {
        args={arg[0], 'listen'}, detached=true, stdio={nil, log, log}
      }, function() end))
      uv.fs_close(log)
      process:unref()
    end
  end)
  uv.run()
  return
end
uv.fs_mkdir(state, 448)
-- Darwin O_CREAT=0x200, O_RDWR=2; the OS releases the lock on exit.
local lock = ffi.C.open(state .. '/lock', 514, ffi.new('int', 384))
assert(lock >= 0, 'Cannot open listener lock')
if ffi.C.flock(lock, 6) ~= 0 then return end -- LOCK_EX | LOCK_NB
write_file(state .. '/pid', tostring(uv.os_getpid()))
uv.fs_unlink(socket_path)
local rows, occupied, children = {}, {}, {}
local stopping, refreshing, dirty = false, false, false
local timer = uv.new_timer()
local reconnect = uv.new_timer()
local refresh
local latest_workspace
local function spawn(command, args, callback)
  local pipe = uv.new_pipe(false)
  local output, exited, ended, code = {}, false, false, 0
  local handle
  local timeout = uv.new_timer()
  local function done()
    if exited and ended and not stopping then callback(code, table.concat(output)) end
  end
  handle = assert(uv.spawn(command, {args=args, stdio={nil, pipe, 2}}, function(status)
    code, exited = status, true
    timeout:stop(); timeout:close()
    children[handle] = nil
    handle:close()
    done()
  end))
  children[handle] = true
  timeout:start(15000, 0, function() handle:kill('sigterm') end)
  pipe:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then output[#output+1] = chunk else
      ended = true; pipe:close(); done()
    end
  end)
end
local function schedule(delay)
  if not stopping then timer:start(delay or 150, 0, function() refresh() end) end
end
local function hex(s)
  return (s:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end
local function highlight(workspace)
  local monitor
  for _, row in ipairs(rows) do
    if row.workspace == hex(workspace) then monitor = row['monitor-appkit-nsscreen-screens-id'] end
  end
  if not monitor then schedule(0); return end
  local args = {}
  for _, row in ipairs(rows) do
    if row['monitor-appkit-nsscreen-screens-id'] == monitor then
      local active = row.workspace == hex(workspace)
      for _, value in ipairs({'--set', 'aerospace.workspace.' .. row.workspace,
        'drawing=' .. ((active or occupied[row.workspace]) and 'on' or 'off'),
        'icon.color=' .. (active and '0xff1e1e2e' or '0xffcdd6f4'),
        'label.drawing=' .. (active and 'on' or 'off'),
        'background.color=' .. (active and '0xff89b4fa' or '0x30313244')}) do
        args[#args+1] = value
      end
    end
  end
  spawn('sketchybar', args, function() end)
end
refresh = function()
  if refreshing then dirty = true; return end
  refreshing, dirty = true, false
  spawn('python3', {directory .. '/status.py', 'aerospace-snapshot'}, function(code, output)
    refreshing = false
    if code == 0 then
      rows, occupied = {}, {}
      for name, monitor, full in output:gmatch('(%x+)\t(%d+)\t([01])') do
        rows[#rows+1] = {workspace=name, ['monitor-appkit-nsscreen-screens-id']=tonumber(monitor)}
        occupied[name] = full == '1'
      end
    else schedule(2000) end
    if latest_workspace then highlight(latest_workspace) end
    if dirty then schedule() end
  end)
end
local function subscribe()
  local pipe, buffer = uv.new_pipe(false), ''
  local process
  process = assert(uv.spawn('aerospace', {
    args={'subscribe', 'focused-workspace-changed', 'focused-monitor-changed', 'window-detected'},
    stdio={nil, pipe, 2}
  }, function()
    children[process] = nil
    process:close()
    if not stopping then reconnect:start(2000, 0, subscribe) end
  end))
  children[process] = true
  pipe:read_start(function(err, chunk)
    assert(not err, err)
    if not chunk then pipe:close(); return end
    buffer = buffer .. chunk
    local latest
    while true do
      local stop = buffer:find('\n', 1, true)
      if not stop then break end
      local event = json.decode(buffer:sub(1, stop-1))
      buffer = buffer:sub(stop+1)
      if event._event == 'focused-workspace-changed' then latest = event.workspace end
    end
    if latest then
      latest_workspace = latest
      if refreshing then dirty = true end
      highlight(latest)
    end
    schedule()
  end)
end
local server = uv.new_pipe(false)
assert(server:bind(socket_path))
assert(server:listen(16, function(err)
  assert(not err, err)
  local client = uv.new_pipe(false)
  server:accept(client)
  client:read_start(function(read_err, chunk)
    if chunk and chunk == 'refresh' then schedule(0) end
    client:read_stop(); client:close()
  end)
end))
local signal = uv.new_signal()
signal:start('sigterm', function()
  stopping = true
  timer:stop(); timer:close(); reconnect:stop(); reconnect:close()
  signal:stop(); signal:close()
  server:close(); uv.fs_unlink(socket_path)
  for child in pairs(children) do child:kill('sigterm') end
end)
subscribe()
refresh()
uv.run()
