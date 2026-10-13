local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
package.path = config .. '/?.lua;' .. config .. '/?/init.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
sbar.begin_config()
sbar.bar({display='all', position='top', topmost='window', y_offset=0,
  blur_radius=30, color=0x40000000})
sbar.default({padding_left=5, padding_right=5,
  icon={font='Hack Nerd Font:Bold:14.0', color=0xffffffff, padding_left=4, padding_right=4},
  label={font='Hack Nerd Font:Bold:12.0', color=0xffffffff, padding_left=4, padding_right=4}})
-- Precreate persistent workspaces so their position precedes the mode indicator.
local aerospace = require('plugins.aerospace')
aerospace.setup()
require('plugins.front_app')
require('plugins.clock')
require('plugins.battery')
require('plugins.bluetooth')
require('plugins.network')
require('plugins.volume')
require('plugins.display').setup()
sbar.end_config()
sbar.event_loop()
