-- One persistent scutil subscription; no periodic network queries.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local uv = require('luv')
local lifecycle = require('plugins.lifecycle')
local state = lifecycle.directory('network')
local socket_path = state .. '/events.sock'
if arg[1] == 'ensure' then
  local client = uv.new_pipe(false)
  client:connect(socket_path, function(err)
    client:close()
    if not err then return end
    local log = assert(uv.fs_open(state .. '/stream.log', 'a', 384))
    local process = assert(uv.spawn(uv.exepath(), {
      args={arg[0], 'listen'}, detached=true, stdio={nil, log, log}
    }, function() end))
    uv.fs_close(log); process:unref()
  end)
  uv.run(); return
end
local debounce, retry = uv.new_timer(), uv.new_timer()
local process, input, output
local stopping = false
local server = uv.new_pipe(false)
local guard = lifecycle.guard(state, nil, function()
  stopping = true
  debounce:stop(); debounce:close(); retry:stop(); retry:close()
  server:close(); uv.fs_unlink(socket_path)
  if process then process:kill('sigterm') end
end)
if not guard then debounce:close(); retry:close(); server:close(); uv.run(); return end
uv.fs_unlink(socket_path)
assert(server:bind(socket_path))
assert(server:listen(16, function(err)
  if err then return end
  local client = uv.new_pipe(false); server:accept(client); client:close()
end))
local function trigger()
  if stopping then return end
  debounce:start(150, 0, function()
    local child
    child = uv.spawn('sketchybar', {args={'--trigger', 'network_change'}}, function()
      if child then child:close() end
    end)
  end)
end
local function subscribe()
  input, output = uv.new_pipe(false), uv.new_pipe(false)
  process = assert(uv.spawn('/usr/sbin/scutil', {stdio={input, output, 2}}, function()
    process:close(); process = nil
    if not input:is_closing() then input:close() end
    if not stopping then retry:start(1000, 0, subscribe) end
  end))
  output:read_start(function(err, chunk)
    if not chunk then output:close(); return end
    if err then io.stderr:write(err, '\n'); return end
    if stopping then return end
    if chunk:find('changed', 1, true) or chunk:find('State:/Network/', 1, true)
        or chunk:find('Setup:/Network/', 1, true) then trigger() end
  end)
  -- Restrict runtime changes to physical en interfaces; ignore TUN/DNS routes.
  input:write('n.add State:/Network/Interface/en[0-9]+/(Link|AirPort|IPv4|IPv6) pattern\n'
    .. 'n.add State:/Network/Interface\n'
    .. 'n.add Setup:/Network/Service/.*/Interface pattern\n'
    .. 'n.watch\n')
  trigger() -- Refresh once after initial subscription or recovery.
end
subscribe()
uv.run()
guard.release()
