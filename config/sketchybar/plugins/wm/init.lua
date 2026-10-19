-- Selection is shared by skhd and SketchyBar, rather than guessed from processes.
local config = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'
local file = io.open(config .. '/wm/backend', 'r')
local backend = file and file:read('*l') or 'aerospace'
if file then file:close() end
assert(backend == 'aerospace' or backend == 'omniwm', 'Unknown WM backend: ' .. tostring(backend))
return {backend=backend}
