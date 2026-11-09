-- Size SketchyBar to the native menu bar without changing AeroSpace gaps.
local sbar = require('sketchybar')
local util = require('plugins.util')
local display = require('plugins.wm.display')
local M = {}
function M.plan(screens)
  local monitors = {}
  for _, screen in ipairs(screens) do
    monitors[#monitors+1] = {['monitor-id']=screen.screen,
      ['monitor-appkit-nsscreen-screens-id']=screen.screen}
  end
  local properties = display.plan(screens, monitors)
  return properties
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
    util.macos(display.metrics, function(screens, code)
      local ok, properties = false, nil
      if code == 0 and type(screens) == 'table' then
        ok, properties = pcall(M.plan, screens)
      end
      busy = false
      if ok then
        sbar.bar(properties)
      else
        io.stderr:write('display: Cannot measure menu bar height\n')
        if attempt < 3 then sbar.delay(1, function() sync(attempt+1) end); return end
      end
      if dirty then sbar.delay(0.25, sync) end
    end)
  end
  item:subscribe('forced', function() sync() end)
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
