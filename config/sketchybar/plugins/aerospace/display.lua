local sbar = require('sketchybar')
local util = require('plugins.util')
local uv = require('luv')
local config_files = require('plugins.wm.config')
local display = require('plugins.wm.display')
local M = {}
local metrics, read = display.metrics, config_files.read
function M.plan(screens, monitors)
  local properties, gaps, fallback = display.plan(screens, monitors)
  local rules = {}
  for _, gap in ipairs(gaps) do rules[#rules+1] = ('{ monitor."%s" = %s }'):format(gap.id, gap.top) end
  rules[#rules+1] = tostring(fallback)
  return properties, 'outer.top = [' .. table.concat(rules, ', ') .. '] # managed by SketchyBar', gaps
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
      util.exec("aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}' --json", function(monitors, monitor_code)
        if monitor_code ~= 0 or type(monitors) ~= 'table' then finish('Cannot list monitors'); return end
        local ok, properties, gap_line = pcall(M.plan, screens, monitors)
        if not ok then finish(properties); return end
        util.exec('aerospace config --config-path', function(config, config_code)
          if config_code ~= 0 then finish('Cannot find AeroSpace config'); return end
          local runtime_path = uv.fs_realpath(util.trim(config))
          if not runtime_path then finish('Cannot resolve AeroSpace config'); return end
          local directory = runtime_path:match('^(.*)/')
          local shared_path, path = config_files.paths('aerospace', directory)
          if not uv.fs_stat(shared_path) then finish('Run install.sh to install shared/local configs'); return end
          local success, original, updated = pcall(function()
            local source, count = read(path), 0
            local result = source:gsub('[^\n]+', function(line)
              if line:match('^outer%.top%s*=') then
                count = count + 1; return gap_line
              end
              return line
            end)
            assert(count <= 1, 'Expected at most one local outer.top line')
            if count == 0 then
              assert(not source:match('%[gaps%]'), 'Add outer.top to the local gaps section')
              result = source .. '\n[gaps]\n' .. gap_line .. '\n'
            end
            return source, result
          end)
          if not success then finish(original); return end
          sbar.bar(properties)
          local written, changed = pcall(function()
            config_files.write(path, updated)
            local _, changed = config_files.generate('aerospace', directory)
            return changed
          end)
          if not written then finish(changed); return end
          if not changed then finish(); return end
          util.exec('aerospace reload-config', function(_, reload_code)
            if reload_code == 0 then finish(); return end
            -- Restore only our own edit if the user has not changed the file.
            if read(path) == updated then
              config_files.write(path, original)
              config_files.generate('aerospace', directory)
            end
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
