-- Separate event loop: forward Rift's JSON stream to SbarLua callbacks.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
local uv, lfs, json = require('luv'), require('lfs'), require('dkjson')
arg[0] = assert(uv.fs_realpath(arg[0]))
-- SbarLua ignores SIGCHLD for its own forks. The stream uses libuv child
-- handles, which need exit status to remain available for reaping.
local child_signal = uv.new_signal()
child_signal:start('sigchld', function() end)
local state = '/tmp/sketchybar-rift-' .. uv.os_get_passwd().uid
local socket_path = state .. '/events.sock'
local function write(path, value)
  local file = assert(io.open(path, 'w')); file:write(value); file:close()
end
local function forward(event)
  if event.type == 'workspace_changed' or event.type == 'windows_changed'
      or event.type == 'binding_mode_changed' or event.type == 'config_changed' then
    sbar.trigger('rift_event', {EVENT=event.type,
      WORKSPACE=event.workspace_name or '', DISPLAY=event.display_uuid or '', MODE=event.mode or ''})
  end
end
if arg[1] == 'ensure' then
  local client = uv.new_pipe(false)
  client:connect(socket_path, function(err)
    if not err then
      client:write('initial', function() client:close() end)
    else
      client:close(); uv.fs_mkdir(state, 448)
      local log = assert(uv.fs_open(state .. '/stream.log', 'w', 384))
      local process = assert(uv.spawn(uv.exepath(), {
        args={arg[0], 'listen'}, detached=true, stdio={nil, log, log}
      }, function() end))
      uv.fs_close(log); process:unref()
    end
  end)
  -- Only connection/process startup keeps this short-lived check alive.
  child_signal:unref()
  uv.run(); child_signal:stop(); child_signal:close(); return
end
uv.fs_mkdir(state, 448)
local lock = assert(io.open(state .. '/stream.lock', 'w'))
if not lfs.lock(lock, 'w') then return end
write(state .. '/stream.pid', ('%d'):format(uv.os_getpid()))
uv.fs_unlink(socket_path)
local latest = {}
local processes, outputs, reconnects = {}, {}, {}
local stopping = false
local function subscribe(kind)
  local buffer = ''
  local output = uv.new_pipe(false)
  outputs[kind] = output
  local process
  process = assert(uv.spawn('rift-cli', {
    args={'subscribe', 'mach', kind},
    stdio={nil, output, 2}
  }, function()
    process:close(); processes[kind] = nil
    if not stopping then reconnects[kind]:start(2000, 0, function() subscribe(kind) end) end
  end))
  processes[kind] = process
  output:read_start(function(err, chunk)
    if not chunk then output:close(); outputs[kind] = nil; return end
    if err then io.stderr:write(err, '\n'); return end
    buffer = buffer .. chunk
    while true do
      local stop = buffer:find('\n', 1, true)
      if not stop then break end
      local event, _, decode_error = json.decode(buffer:sub(1, stop-1))
      buffer = buffer:sub(stop+1)
      if event then
        if event.type == 'binding_mode_changed' then latest.mode = event end
        forward(event)
      else io.stderr:write(tostring(decode_error), '\n') end
    end
  end)
end
local server = uv.new_pipe(false)
assert(server:bind(socket_path))
assert(server:listen(16, function(err)
  assert(not err, err)
  local client = uv.new_pipe(false); server:accept(client)
  client:read_start(function(_, chunk)
    if chunk then for _, event in pairs(latest) do forward(event) end end
    client:read_stop(); client:close()
  end)
end))
local signal = uv.new_signal()
signal:start('sigterm', function()
  stopping = true
  signal:stop(); signal:close()
  for _, timer in pairs(reconnects) do timer:stop(); timer:close() end
  child_signal:stop(); child_signal:close()
  server:close(); uv.fs_unlink(socket_path)
  for _, process in pairs(processes) do process:kill('sigterm') end
end)
-- Subscribe only to bar-relevant events: wildcard would serialize every layout tree.
for _, kind in ipairs({'workspace_changed','windows_changed','binding_mode_changed','config_changed'}) do
  reconnects[kind] = uv.new_timer()
  subscribe(kind)
end
uv.run()
lock:close()
