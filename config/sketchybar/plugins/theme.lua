-- Semantic colors shared by every item. Read once per configuration reload.
local palettes = {
  dark={bar=0x40000000, text=0xffffffff, muted=0xff9399b2,
    workspace_text=0xffcdd6f4, workspace=0x30313244, accent=0xff89b4fa, badge=0xffb8cbe3, active_workspace=0xffb8cbe3,
    on_accent=0xff1e1e2e, connected=0xffa6e3a1, mode=0xfffab387},
  light={bar=0x40eff1f5, text=0xff202331, muted=0xff505568,
    workspace_text=0xff202331, workspace=0x30ffffff, accent=0xff1e66f5,
    badge=0xffb3cbe8, active_workspace=0xffb3cbe8,
    on_accent=0xff202331, connected=0xff007a50, mode=0xff804000,
    workspace_font_style='Bold'},
}
local handle = io.popen('/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null')
local appearance = handle and handle:read('*a') or ''
if handle then handle:close() end
local palette = palettes[appearance:match('Dark') and 'dark' or 'light']
return setmetatable({palettes=palettes}, {__index=palette})
