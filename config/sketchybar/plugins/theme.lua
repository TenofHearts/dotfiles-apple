-- Semantic colors shared by every item. Read once per configuration reload.
local palettes = {
  dark={bar=0x40000000, text=0xffffffff, muted=0xff9399b2,
    workspace_text=0xffcdd6f4, workspace=0x30313244, accent=0xff89b4fa,
    on_accent=0xff1e1e2e, connected=0xffa6e3a1, mode=0xfffab387},
  light={bar=0xbbeff1f5, text=0xff4c4f69, muted=0xff7c7f93,
    workspace_text=0xff4c4f69, workspace=0x30acb0be, accent=0xff1e66f5,
    on_accent=0xffffffff, connected=0xff287d32, mode=0xffa65400},
}
local handle = io.popen('/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null')
local appearance = handle and handle:read('*a') or ''
if handle then handle:close() end
local palette = palettes[appearance:match('Dark') and 'dark' or 'light']
return setmetatable({palettes=palettes}, {__index=palette})
