local util = require('plugins.util')
local M = {}
-- The signed release bundles its CLI; a Homebrew symlink is not required.
M.executable = 'omniwmctl'
for _, bundled in ipairs({'/Applications/OmniWM.app/Contents/MacOS/omniwmctl',
    os.getenv('HOME') .. '/Applications/OmniWM.app/Contents/MacOS/omniwmctl'}) do
  local file = io.open(bundled, 'r')
  if file then file:close(); M.executable = bundled; break end
end
M.cli = util.quote(M.executable)
M.screens = [=[
ObjC.import('AppKit');
$.NSApplication.sharedApplication;
var screens = $.NSScreen.screens, result = [];
for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i);
    result.push({screen: i + 1,
        displayId: Number(ObjC.unwrap(screen.deviceDescription.objectForKey('NSScreenNumber')))});
}
JSON.stringify(result);
]=]
function M.payload(envelope)
  assert(type(envelope) == 'table' and envelope.ok == true, 'OmniWM query failed')
  return assert(envelope.result and envelope.result.payload, 'Missing OmniWM payload')
end
function M.rows(envelope, screens)
  local ids, rows, occupied = {}, {}, {}
  for _, screen in ipairs(screens) do ids['display:' .. screen.displayId] = screen.screen end
  for _, workspace in ipairs(assert(M.payload(envelope).workspaces)) do
    local display = workspace.display and ids[workspace.display.id]
    assert(display, 'Display topology is changing')
    rows[#rows+1] = {workspace=workspace.rawName, ['workspace-is-visible']=workspace.isVisible,
      ['monitor-appkit-nsscreen-screens-id']=display}
    if workspace.counts and workspace.counts.total > 0 then
      occupied[#occupied+1] = {workspace=workspace.rawName}
    end
  end
  return rows, occupied
end
-- Ignore native focus-only snapshots that do not change the bar's workspace
-- state. In particular, a focused-window change must not spawn JXA processes.
function M.event_key(event)
  local payload = event.result and event.result.payload or {}
  if event.channel == 'active-workspace' then
    return payload.workspace and payload.workspace.id or ''
  elseif event.channel == 'focused-monitor' then
    return payload.display and payload.display.id or ''
  elseif event.channel == 'windows-changed' then
    local windows = {}
    for _, window in ipairs(payload.windows or {}) do
      windows[#windows+1] = window.id .. ':' .. (window.workspace and window.workspace.id or '')
    end
    table.sort(windows)
    return table.concat(windows, '\n')
  elseif event.channel == 'display-changed' then
    local displays = {}
    for _, monitor in ipairs(payload.displays or {}) do
      -- Current monitor / active workspace changes have their own channels.
      displays[#displays+1] = {id=monitor.id, frame=monitor.frame, visibleFrame=monitor.visibleFrame,
        hasNotch=monitor.hasNotch, innerGap=monitor.innerGap, outerGapTop=monitor.outerGapTop,
        outerGapLeft=monitor.outerGapLeft, outerGapRight=monitor.outerGapRight,
        outerGapBottom=monitor.outerGapBottom, fullscreenUsesOuterGaps=monitor.fullscreenUsesOuterGaps}
    end
    return require('dkjson').encode(displays, {keyorder={'id', 'frame', 'visibleFrame', 'hasNotch',
      'innerGap', 'outerGapTop', 'outerGapLeft', 'outerGapRight', 'outerGapBottom', 'fullscreenUsesOuterGaps',
      'x', 'y', 'width', 'height'}})
  end
end
function M.center_mouse(display)
  local id = assert(display:match('^display:(%d+)$'), 'Invalid display ID')
  local script = [=[
ObjC.import('AppKit'); ObjC.import('CoreGraphics');
$.NSApplication.sharedApplication;
var screens = $.NSScreen.screens;
var ceiling = screens.objectAtIndex(0).frame.origin.y + screens.objectAtIndex(0).frame.size.height;
for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i), frame = screen.frame;
    if (Number(ObjC.unwrap(screen.deviceDescription.objectForKey('NSScreenNumber'))) === ]=] .. id .. [=[) {
        var mouse = $.NSEvent.mouseLocation;
        if (mouse.x < frame.origin.x || mouse.x >= frame.origin.x + frame.size.width ||
            mouse.y < frame.origin.y || mouse.y >= frame.origin.y + frame.size.height) {
            $.CGWarpMouseCursorPosition({x: frame.origin.x + frame.size.width / 2,
                y: ceiling - frame.origin.y - frame.size.height / 2});
        }
    }
}
'ok';
]=]
  -- This helper also runs in the libuv-only stream, where SbarLua's callback
  -- event loop is absent. Reap the bridge through libuv just like the CLI.
  local uv = require('luv')
  local process
  process = uv.spawn('/usr/bin/osascript', {args={'-l', 'JavaScript', '-e', script},
    stdio={nil, nil, 2}}, function() if process then process:close() end end)
  if not process then io.stderr:write('Cannot center mouse on focused monitor\n') end
end
return M
