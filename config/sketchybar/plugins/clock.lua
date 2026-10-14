local sbar = require('sketchybar')
local weekdays = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}
local item = sbar.add('item', 'clock', {position='right', update_freq=10,
  icon={font='SF Pro Text:Semibold:9.0', color=0xff1e1e2e,
    padding_left=4, padding_right=4,
    background={drawing=true, color=0xff89b4fa, height=12, corner_radius=3}},
  label={padding_left=7}})
item:subscribe({'forced', 'routine', 'system_woke'}, function()
  local now = os.time()
  item:set({icon=weekdays[os.date('*t', now).wday], label=os.date('%m/%d %H:%M', now)})
end)
