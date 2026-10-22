-- Separate event loop: forward OmniWM's JSON stream to SbarLua callbacks.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
local uv, json = require('luv'), require('dkjson')
local lifecycle = require('plugins.lifecycle')
-- SbarLua ignores SIGCHLD for its own forks. The stream uses libuv child
-- handles, which need exit status to remain available for reaping.
local child_signal = uv.new_signal()
child_signal:start('sigchld', function() end)
local state = lifecycle.directory('omniwm')
local socket_path = state .. '/events.sock'
local state_api = require('plugins.omniwm.state')
local fingerprints = {}
local window_fingerprints = {}
local window_state = require('plugins.omniwm.window-state')
local function forward(event, replay)
  if event.kind ~= 'event' or not event.ok then return end
  local payload = event.result and event.result.payload or {}
  local projected = window_state.project(event.channel, payload)
  if projected then
    local data = json.encode(projected, {keyorder={'window', 'windows', 'workspace', 'id', 'rawName',
      'displayName', 'number', 'app', 'bundleId', 'name', 'title', 'isFocused', 'isVisible',
      'columnIndex', 'mode', 'hiddenReason', 'position', 'x', 'top', 'width', 'height'}})
    if replay or window_fingerprints[event.channel] ~= data then
      window_fingerprints[event.channel] = data
      sbar.trigger('omniwm_windows', {EVENT=event.channel, DATA=data})
    end
  end
  -- Replaying independent channel snapshots must not change workspace pills:
  -- their timestamps differ. The controller queries authoritative workspaces.
  if replay then return end
  -- Focus updates must not run workspace queries or JXA display measurements.
  if event.channel == 'focus' then
    local workspace = payload.window and payload.window.workspace
    if workspace then sbar.trigger('omniwm_event', {EVENT='focus', WORKSPACE=workspace.rawName}) end
    return
  end
  local fingerprint = state_api.event_key(event)
  if not replay and fingerprint and fingerprints[event.channel] == fingerprint then return end
  fingerprints[event.channel] = fingerprint
  local workspace = payload.workspace or payload.activeWorkspace
  sbar.trigger('omniwm_event', {EVENT=event.channel,
    WORKSPACE=type(workspace) == 'table' and workspace.rawName or ''})
end
if arg[1] == 'ensure' then
  local client = uv.new_pipe(false)
  client:connect(socket_path, function(err)
    if not err then
      local action = arg[2] == 'replay' and 'initial' or arg[2] == 'refresh' and 'refresh' or 'check'
      client:write(action, function() client:close() end)
    else
      client:close()
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
local latest = {}
local process
local stopping = false
local refreshing = false
local subscription_generation = 0
local reconnect = uv.new_timer()
local server = uv.new_pipe(false)
local function close_child_signal() child_signal:stop(); child_signal:close() end
local guard = lifecycle.guard(state, 'omniwm', function()
  stopping = true
  reconnect:stop(); reconnect:close()
  server:close(); uv.fs_unlink(socket_path)
  if process then process:kill('sigterm') else close_child_signal() end
end)
if not guard then
  reconnect:close(); server:close(); close_child_signal(); uv.run(); return
end
uv.fs_unlink(socket_path)
local function subscribe()
  subscription_generation = subscription_generation + 1
  local version = subscription_generation
  latest, fingerprints, window_fingerprints = {}, {}, {}
  local buffer = ''
  local output = uv.new_pipe(false)
  process = assert(uv.spawn(state_api.executable, {
    args={'subscribe', 'focus,active-workspace,focused-monitor,windows-changed,display-changed', '--format', 'ndjson'},
    stdio={nil, output, 2}
  }, function()
    process:close(); process = nil
    if stopping then close_child_signal()
    else
      reconnect:start(refreshing and 0 or 2000, 0, subscribe)
      refreshing = false
    end
  end))
  output:read_start(function(err, chunk)
    if not chunk then output:close(); return end
    if err then io.stderr:write(err, '\n'); return end
    if version ~= subscription_generation then return end -- Discard old subscription data.
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
assert(server:bind(socket_path))
assert(server:listen(16, function(err)
  assert(not err, err)
  local client = uv.new_pipe(false); server:accept(client)
  client:read_start(function(_, chunk)
    if chunk == 'initial' then
      for _, channel in ipairs({'active-workspace', 'focused-monitor', 'windows-changed', 'focus', 'display-changed'}) do
        if latest[channel] then forward(latest[channel], true) end
      end
    elseif chunk == 'refresh' then
      -- Wake needs fresh native snapshots, not the pre-sleep channel cache.
      subscription_generation = subscription_generation + 1
      if process then refreshing = true; process:kill('sigterm')
      else reconnect:start(0, 0, subscribe) end
    end
    client:read_stop(); client:close()
  end)
end))
if guard.selected() then subscribe() else guard.stop() end
uv.run()
guard.release()
