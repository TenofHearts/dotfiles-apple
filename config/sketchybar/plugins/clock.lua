local sbar = require('sketchybar')
local theme = require('plugins.theme')
local spacing = require('plugins.spacing')
local weekdays = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}
-- Right-side items are placed from right to left; time follows the date visually.
local time = sbar.add('item', 'clock.time', {position='right',
  padding_left=spacing.inside/2, padding_right=math.ceil(spacing.between/2),
  icon={drawing=false}, label={padding_left=0}})
local item = sbar.add('item', 'clock', {position='right', update_freq=10,
  padding_right=spacing.inside/2,
  icon={font='Hack Nerd Font:Bold:9.0', color=theme.on_accent,
    padding_left=4, padding_right=4,
    background={drawing=true, color=theme.accent, height=12, corner_radius=3}},
  label={padding_left=spacing.inside}})
item:subscribe({'forced', 'routine', 'system_woke'}, function()
  local now = os.time()
  item:set({icon=weekdays[os.date('*t', now).wday], label=os.date('%m/%d', now)})
  time:set({label=os.date('%H:%M', now)})
end)
