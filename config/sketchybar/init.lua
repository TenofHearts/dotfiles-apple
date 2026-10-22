local config = os.getenv('CONFIG_DIR') or os.getenv('HOME') .. '/.config/sketchybar'
package.path = config .. '/?.lua;' .. config .. '/?/init.lua;' .. package.path
require('runtime')
local sbar = require('sketchybar')
local spacing = require('plugins.spacing')
local theme = require('plugins.theme')
sbar.begin_config()
sbar.bar({display='all', position='top', topmost=false, y_offset=0,
  blur_radius=30, color=theme.bar})
sbar.default({padding_left=math.floor(spacing.between/2), padding_right=math.ceil(spacing.between/2),
  icon={font='Hack Nerd Font:Bold:14.0', color=theme.text, padding_left=0, padding_right=0},
  label={font='Hack Nerd Font:Bold:12.0', color=theme.text, padding_left=spacing.inside, padding_right=0}})
-- Precreate persistent workspaces so their position precedes the mode indicator.
local backend = require('plugins.wm').backend
require('plugins.' .. backend).setup()
require(backend == 'omniwm' and 'plugins.omniwm.windows' or 'plugins.front_app')
require('plugins.clock')
require('plugins.battery')
require('plugins.bluetooth')
require('plugins.network')
require('plugins.volume')
require('plugins.' .. backend .. '.display').setup()
require('plugins.wake')
-- macOS posts this distributed notification for both manual and scheduled changes.
sbar.add('event', 'appearance_changed', 'AppleInterfaceThemeChangedNotification')
local appearance = sbar.add('item', 'appearance.listener', {drawing=false})
local appearance_generation = 0
appearance:subscribe('appearance_changed', function()
  appearance_generation = appearance_generation + 1
  local generation = appearance_generation
  sbar.delay(0.2, function()
    if generation == appearance_generation then sbar.exec('sketchybar --reload') end
  end)
end)
sbar.end_config()
sbar.event_loop()
