-- Copy AeroSpace's measured-menu gaps, settling, retries, and atomic writes.
local sbar = require('sketchybar')
local util = require('plugins.util')
local state = require('plugins.omniwm.state')
local display = require('plugins.wm.display')
local uv = require('luv')
local json = require('dkjson')
local config_files = require('plugins.wm.config')
local M = {}
local first = '# BEGIN sketchybar managed OmniWM gaps'
local last = '# END sketchybar managed OmniWM gaps'
local metrics = display.metrics:gsub("ObjC.import%('CoreGraphics'%);", [=[ObjC.import('CoreGraphics');
ObjC.bindFunction('CGDisplayCreateUUIDFromDisplayID', ['id', ['unsigned int']]);]=])
metrics = metrics:gsub('screen: i %+ 1,', [=[screen: i + 1,
        displayId: Number(ObjC.unwrap(screen.deviceDescription.objectForKey('NSScreenNumber'))),
        uuid: ObjC.unwrap(ObjC.castRefToObject($.CFUUIDCreateString(null, $.CGDisplayCreateUUIDFromDisplayID(
            Number(ObjC.unwrap(screen.deviceDescription.objectForKey('NSScreenNumber'))))))),]=])
M.metrics = metrics
function M.bar_properties(screens)
  local monitors = {}
  for _, screen in ipairs(screens) do
    monitors[#monitors+1] = {['monitor-id']=screen.screen,
      ['monitor-appkit-nsscreen-screens-id']=screen.screen}
  end
  return display.plan(screens, monitors)
end
function M.plan(screens, envelope)
  local monitors, by_id, screen_ids = {}, {}, {}
  for _, screen in ipairs(screens) do screen_ids['display:' .. screen.displayId] = screen.screen end
  for _, monitor in ipairs(assert(state.payload(envelope).displays)) do
    local screen = assert(screen_ids[monitor.id], 'Display topology is changing')
    monitors[#monitors+1] = {['monitor-id']=screen, ['monitor-appkit-nsscreen-screens-id']=screen}
    by_id[screen] = monitor
  end
  local properties, gaps = display.plan(screens, monitors)
  local lines = {first}
  for _, gap in ipairs(gaps) do
    local monitor, screen = by_id[gap.id], screens[gap.id]
    assert(screen.uuid and screen.uuid ~= '', 'Display UUID unavailable')
    lines[#lines+1] = '[[monitorGapOverrides]]'
    -- Stable identity, so live reload does not continually create new overrides.
    lines[#lines+1] = 'id = ' .. json.encode(screen.uuid)
    lines[#lines+1] = 'monitorName = ' .. json.encode(monitor.name)
    lines[#lines+1] = 'monitorDisplayUUID = ' .. json.encode(screen.uuid)
    -- AeroSpace adds its outer.top below macOS's visible-frame inset. OmniWM
    -- applies an edge inset before intersecting the visible frame, so include
    -- that native inset to preserve the same space below SketchyBar.
    lines[#lines+1] = ('outerGapTop = %.1f'):format(gap.top + screen.inset)
  end
  lines[#lines+1] = last
  return properties, table.concat(lines, '\n')
end
function M.update(source, block)
  -- Patch only measured top gaps in the native file. Preserve all other GUI
  -- settings, including other edges and disconnected displays' overrides.
  local targets, order, current = {}, {}, nil
  local function target()
    if not current then return end
    local uuid, top
    for _, line in ipairs(current) do
      uuid = line:match('^%s*monitorDisplayUUID%s*=%s*"([^"]+)"') or uuid
      top = line:match('^%s*outerGapTop%s*=%s*([%d.]+)') or top
    end
    assert(uuid and top and not targets[uuid], 'Invalid measured gap override')
    targets[uuid] = {lines=current, top=tonumber(top)}
    order[#order+1] = uuid
  end
  for line in (block .. '\n'):gmatch('(.-)\n') do
    if line:match('^%s*%[%[monitorGapOverrides%]%]%s*$') then
      target(); current = {line}
    elseif line ~= first and line ~= last and current then
      current[#current+1] = line
    end
  end
  target()
  assert(#order > 0, 'No measured gap overrides')

  local lines, section, changed = {}, nil, false
  local function flush()
    if not section then return end
    local uuid
    for _, line in ipairs(section) do
      uuid = line:match('^%s*monitorDisplayUUID%s*=%s*"([^"]+)"') or uuid
    end
    local measured = targets[uuid]
    if measured then
      assert(not measured.applied, 'Duplicate display gap override: ' .. uuid)
      measured.applied = true
      local found = false
      for index, line in ipairs(section) do
        if line:match('^%s*outerGapTop%s*=') then
          assert(not found, 'Duplicate outerGapTop'); found = true
          if tonumber(line:match('=%s*([%d.]+)')) ~= measured.top then
            section[index] = ('outerGapTop = %.1f'):format(measured.top)
            changed = true
          end
        end
      end
      if not found then
        section[#section+1] = ('outerGapTop = %.1f'):format(measured.top)
        changed = true
      end
    end
    for _, line in ipairs(section) do lines[#lines+1] = line end
    section = nil
  end
  for line in (source .. '\n'):gmatch('(.-)\n') do
    -- Old composition can drop the opening marker while retaining the closing
    -- one. These are comments, not table boundaries; native tables identify gaps.
    if line == first or line == last then
    elseif line:match('^%s*monitorGapOverrides%s*=') then
      assert(line:match('=%s*%[%]%s*$') or line:match('=%s*%[%]%s*#'),
        'Expected empty monitorGapOverrides or override tables')
      changed = true
    else
      if line:match('^%s*%[') then
        flush()
        if line:match('^%s*%[%[monitorGapOverrides%]%]%s*$') then section = {} end
      end
      local destination = section or lines
      destination[#destination+1] = line
    end
  end
  flush()
  for _, uuid in ipairs(order) do
    if not targets[uuid].applied then
      changed = true
      lines[#lines+1] = ''
      for _, line in ipairs(targets[uuid].lines) do lines[#lines+1] = line end
    end
  end
  -- In particular, do not reload OmniWM just to normalize comments/whitespace
  -- after waking with unchanged menu measurements.
  if not changed then return source end
  return table.concat(lines, '\n'):gsub('%s*$', '') .. '\n'
end
function M.save(runtime_path, block)
  local directory = assert(runtime_path:match('^(.*)/'))
  local _, local_path = config_files.paths('omniwm', directory)
  local file = io.open(local_path, 'r')
  local local_settings = file and file:read('*a') or ''
  if file then file:close() end
  local runtime = M.update(config_files.read(runtime_path), block)
  config_files.write(local_path, M.update(local_settings, block))
  -- Do not regenerate from shared defaults: this file is OmniWM's persisted
  -- source of truth for GUI preferences, layouts, rules, and workspace IDs.
  return config_files.write(runtime_path, runtime)
end
function M.setup()
  local item = sbar.add('item', 'bar.height', {position='left', drawing=false})
  local busy, dirty, settling, generation = false, false, false, 0
  local sync
  sync = function(attempt)
    if settling or busy then dirty = true; return end
    busy, dirty = true, false
    attempt = attempt or 1
    local function finish(error_message)
      busy = false
      if error_message then
        io.stderr:write('omniwm-display: ', tostring(error_message), '\n')
        if attempt < 3 then sbar.delay(1, function() sync(attempt+1) end); return end
      end
      if dirty then sbar.delay(0.25, sync) end
    end
    util.macos(metrics, function(screens, code)
      if code ~= 0 or type(screens) ~= 'table' then finish('Cannot measure menus'); return end
      -- Bar geometry depends only on macOS, so apply it even while OmniWM is
      -- waiting for permissions or restarting and its IPC is unavailable.
      local measured, properties = pcall(M.bar_properties, screens)
      if not measured then finish(properties); return end
      sbar.bar(properties)
      util.exec(state.cli .. ' query displays --json', function(envelope, query_code)
        if query_code ~= 0 then finish('Cannot list monitors'); return end
        local ok, properties, block = pcall(M.plan, screens, envelope)
        if not ok then finish(properties); return end
        local config = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'
        local runtime_path = uv.fs_realpath(config .. '/omniwm/settings.toml')
        if not runtime_path then finish('Cannot resolve OmniWM config'); return end
        local success, error_message = pcall(function()
          M.save(runtime_path, block)
        end)
        finish(not success and error_message or nil)
      end)
    end)
  end
  item:subscribe('forced', function() sync() end)
  item:subscribe('omniwm_event', function(env)
    -- The initial IPC snapshot arrives after first-launch permissions; later
    -- snapshots also cover restarts and gap edits without a macOS display event.
    if env.EVENT == 'display-changed' then sync() end
  end)
  item:subscribe({'display_change', 'system_woke'}, function()
    generation = generation + 1
    local version = generation
    settling = true
    sbar.delay(3, function()
      if version ~= generation then return end
      settling = false
      sync()
    end)
  end)
end
return M
