-- Separate event loop: forward AeroSpace's JSON stream to SbarLua callbacks.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local config = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'
local function selected()
  local file = io.open(config .. '/wm/backend', 'r')
  local backend = file and file:read('*l') or 'aerospace'
  if file then file:close() end
  return backend == 'aerospace'
end
if not selected() then return end
local sbar = require('sketchybar')
local uv, json = require('luv'), require('dkjson')
local lifecycle = require('plugins.lifecycle')
-- SbarLua ignores SIGCHLD for its own forks. The stream uses libuv child
-- handles, which need exit status to remain available for reaping.
local child_signal = uv.new_signal()
child_signal:start('sigchld', function() end)
local state = lifecycle.directory('aerospace')
local socket_path = state .. '/events.sock'
local function forward(event)
  sbar.trigger('aerospace_event', {EVENT=event._event,
    WORKSPACE=event.workspace or '', MODE=event.mode or ''})
end
if arg[1] == 'ensure' then
  local client = uv.new_pipe(false)
  client:connect(socket_path, function(err)
    if not err then
      client:write('initial', function() client:close() end)
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
local process, output
local stopping = false
local server = uv.new_pipe(false)
local function close_child_signal() child_signal:stop(); child_signal:close() end
local guard = lifecycle.guard(state, 'aerospace', function()
  stopping = true
  server:close(); uv.fs_unlink(socket_path)
  if process then process:kill('sigterm') else close_child_signal() end
end)
if not guard then server:close(); close_child_signal(); uv.run(); return end
uv.fs_unlink(socket_path)
local function subscribe()
  local buffer = ''
  output = uv.new_pipe(false)
  process = assert(uv.spawn('aerospace', {
    args={'subscribe', 'focused-workspace-changed', 'focused-monitor-changed', 'window-detected', 'mode-changed'},
    stdio={nil, output, 2}
  }, function()
    process:close(); process = nil
    -- AeroSpace closes the subscription when its server exits. Finish this
    -- helper with that event instead of retrying against a stopped app.
    if stopping then close_child_signal() else guard.stop() end
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
        if event._event == 'mode-changed' or event._event == 'focused-workspace-changed' then
          latest[event._event] = event
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
    if chunk then for _, event in pairs(latest) do forward(event) end end
    client:read_stop(); client:close()
  end)
end))
if guard.selected() then subscribe() else guard.stop() end
uv.run()
guard.release()
