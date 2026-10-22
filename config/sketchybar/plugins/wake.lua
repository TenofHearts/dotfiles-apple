local sbar = require('sketchybar')
local listener = sbar.add('item', 'wake.listener', {drawing=false})
local recovering, generation = false, 0
listener:subscribe({'system_woke', 'display_change'}, function(env)
  if env.SENDER == 'system_woke' then recovering = true end
  if not recovering then return end
  generation = generation + 1
  local version = generation
  sbar.delay(3, function()
    if version ~= generation then return end
    recovering = false
    -- Setting topmost rebuilds native bar/item windows even when unchanged.
    -- Do this after wake's display churn, preserving the configured window level
    -- and all Lua items. A config reload would temporarily empty the bar.
    sbar.bar({topmost=false})
  end)
end)
