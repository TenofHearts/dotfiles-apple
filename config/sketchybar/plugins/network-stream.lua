-- One persistent scutil subscription; no periodic network queries.
local directory = arg[0]:match('^(.*)/plugins/') or os.getenv('CONFIG_DIR')
package.path = directory .. '/?.lua;' .. package.path
require('runtime')
local uv, lfs = require('luv'), require('lfs')
local state = '/tmp/sketchybar-network-' .. uv.os_get_passwd().uid
uv.fs_mkdir(state, 448)
if arg[1] == 'ensure' then
  local log = assert(uv.fs_open(state .. '/stream.log', 'a', 384))
  local process = assert(uv.spawn(uv.exepath(), {
    args={arg[0], 'listen'}, detached=true, stdio={nil, log, log}
  }, function() end))
  uv.fs_close(log); process:unref(); return
end
local lock = assert(io.open(state .. '/stream.lock', 'a'))
if not lfs.lock(lock, 'w') then return end
local pid = assert(io.open(state .. '/stream.pid', 'w'))
pid:write(('%d'):format(uv.os_getpid())); pid:close()
local debounce, retry = uv.new_timer(), uv.new_timer()
local process, input, output
local stopping = false
local function trigger()
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
for _, signal in ipairs({'sigterm', 'sigint'}) do
  local handler = uv.new_signal()
  handler:start(signal, function()
    stopping = true
    if process then process:kill('sigterm') end
    os.exit(0)
  end)
end
subscribe()
uv.run()
