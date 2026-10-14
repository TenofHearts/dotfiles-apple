local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
package.path = config .. '/?.lua;' .. config .. '/?/init.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
local spacing = require('plugins.spacing')
sbar.begin_config()
sbar.bar({display='all', position='top', topmost='window', y_offset=0,
  blur_radius=30, color=0x40000000})
sbar.default({padding_left=math.floor(spacing.between/2), padding_right=math.ceil(spacing.between/2),
  icon={font='Hack Nerd Font:Bold:14.0', color=0xffffffff, padding_left=0, padding_right=0},
  label={font='Hack Nerd Font:Bold:12.0', color=0xffffffff, padding_left=spacing.inside, padding_right=0}})
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
