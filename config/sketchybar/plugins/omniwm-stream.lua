-- Separate event loop: forward OmniWM's JSON stream to SbarLua callbacks.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
local uv, lfs, json = require('luv'), require('lfs'), require('dkjson')
-- SbarLua ignores SIGCHLD for its own forks. The stream uses libuv child
-- handles, which need exit status to remain available for reaping.
local child_signal = uv.new_signal()
child_signal:start('sigchld', function() end)
local state = '/tmp/sketchybar-omniwm-' .. uv.os_get_passwd().uid
local socket_path = state .. '/events.sock'
local function write(path, value)
  local file = assert(io.open(path, 'w')); file:write(value); file:close()
end
local state_api = require('plugins.omniwm-state')
local previous_display
local fingerprints = {}
local function forward(event, replay)
  if event.kind ~= 'event' or not event.ok then return end
  local fingerprint = state_api.event_key(event)
  if not replay and fingerprint and fingerprints[event.channel] == fingerprint then return end
  fingerprints[event.channel] = fingerprint
  local payload = event.result and event.result.payload or {}
  local workspace = payload.workspace or payload.activeWorkspace
  sbar.trigger('omniwm_event', {EVENT=event.channel,
    WORKSPACE=type(workspace) == 'table' and workspace.rawName or ''})
  if event.channel == 'focused-monitor' and type(payload.display) == 'table' then
    local id = payload.display.id
    if previous_display and id ~= previous_display then state_api.center_mouse(id) end
    previous_display = id
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
local process, output
local stopping = false
local reconnect = uv.new_timer()
local function subscribe()
  local buffer = ''
  output = uv.new_pipe(false)
  process = assert(uv.spawn(state_api.executable, {
    args={'subscribe', 'active-workspace,focused-monitor,windows-changed,display-changed', '--format', 'ndjson'},
    stdio={nil, output, 2}
  }, function()
    process:close(); process = nil
    if not stopping then reconnect:start(2000, 0, subscribe) end
  end))
  output:read_start(function(err, chunk)
    if not chunk then output:close(); return end
    if err then io.stderr:write(err, '\n'); return end
    buffer = buffer .. chunk
    while true do
      local stop = buffer:find('\n', 1, true)
      if not stop then break end
      local event, _, decode_error = json.decode(buffer:sub(1, stop-1))
      buffer = buffer:sub(stop+1)
      if event then
        if event.kind == 'event' then
          latest[event.channel] = event
        end
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
    if chunk then for _, event in pairs(latest) do forward(event, true) end end
    client:read_stop(); client:close()
  end)
end))
local signal = uv.new_signal()
signal:start('sigterm', function()
  stopping = true
  signal:stop(); signal:close(); reconnect:stop(); reconnect:close()
  child_signal:stop(); child_signal:close()
  server:close(); uv.fs_unlink(socket_path)
  if process then process:kill('sigterm') end
end)
subscribe()
uv.run()
lock:close()
