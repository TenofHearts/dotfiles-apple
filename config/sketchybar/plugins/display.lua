local sbar = require('sketchybar')
local util = require('plugins.util')
local uv = require('luv')
local M = {}
local marker = '# managed by sketchybar display.lua'
local metrics = [=[
ObjC.import('AppKit');
ObjC.import('CoreGraphics');
$.NSApplication.sharedApplication;
var windows = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0)));
var screens = $.NSScreen.screens;
var primary = screens.objectAtIndex(0).frame;
var ceiling = primary.origin.y + primary.size.height;
var result = [];
for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i);
    var frame = screen.frame;
    var visible = screen.visibleFrame;
    var top = ceiling - frame.origin.y - frame.size.height;
    // Hidden menus sit just above the screen; visible menus sit at its top.
    var menus = windows.filter(function(w) {
        var b = w.kCGWindowBounds;
        return w.kCGWindowLayer === 24 && b &&
            w.kCGWindowOwnerName === 'Window Server' &&
            Math.abs(b.X - frame.origin.x) < 1 &&
            Math.abs(b.Width - frame.size.width) < 1 &&
            b.Height > 0 && b.Height < 100 &&
            Math.abs(b.Y - top) <= b.Height + 1;
    });
    result.push({
        screen: i + 1,
        raw_top: top,
        screen_id: ObjC.unwrap(screen.deviceDescription.objectForKey("NSScreenNumber")),
        notch: screen.safeAreaInsets.top > 0,
        inset: Math.max(0, frame.origin.y + frame.size.height -
            visible.origin.y - visible.size.height),
        height: menus.length ? Math.min.apply(null, menus.map(function(w) {
            return w.kCGWindowBounds.Height;
        })) : null
    });
}
JSON.stringify(result);
]=]
function M.plan(screens, monitors)
  assert(#screens > 0, 'No display measurements')
  local heights, ids, seen = {}, {}, {}
  for _, screen in ipairs(screens) do
    assert(type(screen.height) == 'number', 'Native menu height is unavailable')
    local kind = screen.notch and 'notch' or 'plain'
    heights[kind] = math.min(heights[kind] or screen.height, screen.height)
  end
  for _, monitor in ipairs(monitors) do
    ids[monitor['monitor-appkit-nsscreen-screens-id']] = monitor['monitor-id']
  end
  local gaps, maximum = {}, 0
  for _, screen in ipairs(screens) do
    local id = assert(ids[screen.screen], 'Display topology is changing')
    seen[screen.screen] = true
    local height = math.floor(heights[screen.notch and 'notch' or 'plain'])
    gaps[#gaps+1] = {id=id, top=math.ceil(math.max(0, height - screen.inset) + 5)}
  end
  for id in pairs(ids) do assert(seen[id], 'Display topology is changing') end
  table.sort(gaps, function(a, b) return a.id < b.id end)
  local rules, properties = {}, {}
  for _, gap in ipairs(gaps) do
    rules[#rules+1] = ('{ monitor."%s" = %s }'):format(gap.id, gap.top)
  end
  for kind, height in pairs(heights) do
    properties[kind == 'notch' and 'notch_display_height' or 'height'] = math.floor(height)
    maximum = math.max(maximum, height)
  end
  rules[#rules+1] = tostring(math.ceil(maximum + 5))
  return properties, 'outer.top = [' .. table.concat(rules, ', ') .. '] ' .. marker
end
local function read(path)
  local file = assert(io.open(path, 'r')); local content = file:read('*a'); file:close(); return content
end
local function replace(path, content)
  local stat = assert(uv.fs_stat(path))
  local temporary = path .. '.sketchybar-' .. uv.os_getpid()
  local fd = assert(uv.fs_open(temporary, 'w', stat.mode & 511))
  local ok, err = pcall(function()
    assert(uv.fs_write(fd, content, 0))
    assert(uv.fs_fsync(fd))
  end)
  uv.fs_close(fd)
  if not ok then uv.fs_unlink(temporary); error(err) end
  assert(uv.fs_rename(temporary, path))
end
function M.rift_plan(screens, monitors)
  assert(#screens > 0, 'No display measurements')
  local heights, ids, seen = {}, {}, {}
  for _, screen in ipairs(screens) do
    assert(type(screen.height) == 'number', 'Native menu height is unavailable')
    local kind = screen.notch and 'notch' or 'plain'
    heights[kind] = math.min(heights[kind] or screen.height, screen.height)
  end
  for _, monitor in ipairs(monitors) do ids[monitor.screen_id] = monitor end
  local properties, rules = {}, {}
  for _, screen in ipairs(screens) do
    local monitor = assert(ids[screen.screen_id], 'Display topology is changing')
    local uuid = monitor.uuid
    assert(uuid:match('^[%x%-]+$'), 'Invalid display UUID')
    seen[screen.screen_id] = true
    local height = math.floor(heights[screen.notch and 'notch' or 'plain'])
    -- Rift already subtracts its native menu/notch inset from the display frame.
    local inset = monitor.frame.origin.y - screen.raw_top
    local top = math.ceil(math.max(0, height - inset) + 5)
    rules[#rules+1] = ('[settings.layout.gaps.per_display."%s".outer]\ntop = %s\nleft = 5\nright = 5\nbottom = 5'):format(uuid, top)
  end
  for id in pairs(ids) do assert(seen[id], 'Display topology is changing') end
  for kind, height in pairs(heights) do
    properties[kind == 'notch' and 'notch_display_height' or 'height'] = math.floor(height)
  end
  table.sort(rules)
  return properties, '# BEGIN managed display gaps\n' .. table.concat(rules, '\n') .. '\n# END managed display gaps'
end
local function sync_rift(screens, finish)
  util.exec('rift-cli query displays', function(monitors, code)
    if code ~= 0 or type(monitors) ~= 'table' or #monitors == 0 then finish('Cannot list Rift displays'); return end
    local ok, properties, gaps = pcall(M.rift_plan, screens, monitors)
    if not ok then finish(properties); return end
    local path = uv.fs_realpath(os.getenv('HOME') .. '/.config/rift/config.toml')
    if not path then finish('Cannot resolve Rift config'); return end
    local success, original, updated = pcall(function()
      local source = read(path)
      local result, count = source:gsub('# BEGIN managed display gaps.-# END managed display gaps', function() return gaps end)
      assert(count == 1, 'Expected one managed Rift gaps block')
      return source, result
    end)
    if not success then finish(original); return end
    sbar.bar(properties)
    if updated == original then finish(); return end
    local written, err = pcall(replace, path, updated)
    if not written then finish(err); return end
    util.exec('rift-cli execute config reload', function(_, reload_code)
      if reload_code == 0 then finish(); return end
      if read(path) == updated then replace(path, original) end
      util.exec('rift-cli execute config reload', function() finish('Rift rejected new gaps') end)
    end)
  end)
end
function M.setup()
  local item = sbar.add('item', 'bar.height', {position='left', drawing=false})
  local busy, dirty = false, false
  local generation, settling = 0, false
  local sync
  sync = function(attempt)
    if settling then dirty = true; return end
    if busy then dirty = true; return end
    busy, dirty = true, false
    attempt = attempt or 1
    local function finish(error_message)
      busy = false
      if error_message then
        io.stderr:write('display: ', tostring(error_message), '\n')
        if attempt < 3 then sbar.delay(1, function() sync(attempt+1) end); return end
      end
      if dirty then sbar.delay(0.25, sync) end
    end
    util.macos(metrics, function(screens, code)
      if code ~= 0 or type(screens) ~= 'table' then finish('Cannot measure menus'); return end
      if require('plugins.window_manager').selected() == 'rift' then
        sync_rift(screens, finish); return
      end
      util.exec("aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}' --json", function(monitors, monitor_code)
        if monitor_code ~= 0 or type(monitors) ~= 'table' then finish('Cannot list monitors'); return end
        local ok, properties, gap_line = pcall(M.plan, screens, monitors)
        if not ok then finish(properties); return end
        util.exec('aerospace config --config-path', function(config, config_code)
          if config_code ~= 0 then finish('Cannot find AeroSpace config'); return end
          local path = uv.fs_realpath(util.trim(config))
          if not path then finish('Cannot resolve AeroSpace config'); return end
          local success, original, updated = pcall(function()
            local source, count = read(path), 0
            local result = source:gsub('[^\n]+', function(line)
              if line:match('^outer%.top = ') and line:find(marker, 1, true) then
                count = count + 1; return gap_line
              end
              return line
            end)
            assert(count == 1, 'Expected one managed outer.top line')
            return source, result
          end)
          if not success then finish(original); return end
          sbar.bar(properties)
          if updated == original then finish(); return end
          local written, write_error = pcall(replace, path, updated)
          if not written then finish(write_error); return end
          util.exec('aerospace reload-config', function(_, reload_code)
            if reload_code == 0 then finish(); return end
            -- Restore only our own edit if the user has not changed the file.
            if read(path) == updated then replace(path, original) end
            util.exec('aerospace reload-config', function() finish('AeroSpace rejected new gaps') end)
          end)
        end)
      end)
    end)
  end
  item:subscribe('forced', function() sync() end)
  -- Wake/Sidecar reconnection can emit several display changes. Wait for a
  -- quiet interval before measuring menus and potentially reloading AeroSpace.
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
