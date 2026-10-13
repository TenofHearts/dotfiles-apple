local sbar = require('sketchybar')
local item = sbar.add('item', 'clock', {position='right', update_freq=10, icon=''})
item:subscribe({'forced', 'routine', 'system_woke'}, function() item:set({label=os.date('%d/%m %H:%M')}) end)
