#!/usr/bin/env lua
-- Close a captured window ID after handing focus to a workspace-local successor.
local M = {}
local function belongs(window, workspace)
  return window.workspace and window.workspace.id == workspace.id
end
local function eligible(window, workspace)
  return belongs(window, workspace) and not window.isAppHidden and not window.isScratchpad
    and window.layoutReason ~= 'native-fullscreen'
    and (not window.hiddenReason or window.hiddenReason == 'tab-inactive')
end
local function focused(windows)
  for _, window in ipairs(windows) do if window.isFocused then return window end end
end
function M.plan(workspace, windows)
  local source = focused(windows)
  if not source or not belongs(source, workspace) then return end
  local candidate, score
  local origin = source.frame or {x=0, y=0, width=0, height=0}
  for _, window in ipairs(windows) do
    if window.id ~= source.id and eligible(window, workspace) then
      local frame = window.frame or origin
      local dx = frame.x + frame.width/2 - origin.x - origin.width/2
      local dy = frame.y + frame.height/2 - origin.y - origin.height/2
      local distance = dx*dx + dy*dy + (window.isVisible == false and 1e12 or 0)
      if not score or distance < score or (distance == score and window.id < candidate.id) then
        candidate, score = window, distance
      end
    end
  end
  return source, candidate
end
function M.close(api)
  local workspace = api.workspace()
  local source, candidate = M.plan(workspace, api.windows())
  if not source then return end
  if candidate then
    api.focus(candidate.id)
    -- CLI acceptance precedes macOS focus delivery. Close only after the handoff.
    local ready = false
    for _=1,15 do
      local current = focused(api.windows())
      if current and current.id == candidate.id then ready = true; break end
      if current and current.id ~= source.id then return end
      api.sleep(20)
    end
    if not ready or api.workspace().id ~= workspace.id then return end
  end
  api.close(source.id)
  -- Window destruction is asynchronous. Only recover after it actually closes;
  -- a save confirmation or cancelled close must retain its own focus.
  for _=1,50 do
    local windows, exists = api.windows(), false
    for _, window in ipairs(windows) do if window.id == source.id then exists = true; break end end
    if not exists then
      local current = focused(windows)
      if current and belongs(current, workspace) then return end
      -- Revalidate the candidate: it may have closed or moved in the meantime.
      local replacement
      for _, window in ipairs(windows) do
        if eligible(window, workspace) then
          replacement = replacement or window
          if candidate and window.id == candidate.id then replacement = window; break end
        end
      end
      if replacement then api.focus(replacement.id)
      elseif api.workspace().id ~= workspace.id then api.activate(workspace.rawName) end
      return
    end
    local current = focused(windows)
    -- Leave a local dialog or later navigation alone. With no successor, macOS
    -- may activate a remote window before OmniWM publishes the destruction.
    if current and belongs(current, workspace) and current.id ~= source.id
        and (not candidate or current.id ~= candidate.id) then return end
    if candidate and api.workspace().id ~= workspace.id then return end
    api.sleep(20)
  end
end
local tree = os.getenv('DOTFILES_LUA_TREE') or os.getenv('HOME') .. '/.local/share/dotfiles-lua'
package.path = tree .. '/share/lua/5.5/?.lua;' .. package.path
package.cpath = tree .. '/lib/lua/5.5/?.so;' .. package.cpath
local uv, json, lfs = require('luv'), require('dkjson'), require('lfs')
local executable = os.getenv('DOTFILES_OMNIWMCTL') or 'omniwmctl'
local function run(...)
  local args = {...}; args[#args+1] = '--json'
  local output, chunks, done, exit_code = uv.new_pipe(false), {}, false, nil
  local process
  process = assert(uv.spawn(executable, {args=args, stdio={nil,output,2}}, function(code)
    exit_code = code; process:close()
  end))
  output:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then chunks[#chunks+1] = chunk else output:close(); done = true end
  end)
  local timeout = uv.new_timer()
  timeout:start(5000, 0, function() process:kill('sigkill') end)
  while not done or exit_code == nil do uv.run('once') end
  timeout:stop(); timeout:close()
  local result, _, err = json.decode(table.concat(chunks))
  assert(result and result.ok, err or (result and result.status) or 'OmniWM did not respond')
  return result.result and result.result.payload or {}
end
local api = {
  workspace=function() return assert(run('query', 'workspaces', '--current').workspaces[1]) end,
  windows=function() return run('query', 'windows').windows end,
  focus=function(id) run('window', 'focus', id) end,
  close=function(id) run('window', 'close', id) end,
  activate=function(name) run('workspace', 'focus-name', name) end,
  sleep=uv.sleep,
}
local ok, err = pcall(function()
  if arg[1] == '--dry-run' then
    local source, candidate = M.plan(api.workspace(), api.windows())
    print(json.encode({close=source and source.id or json.null, successor=candidate and candidate.id or json.null}))
    return
  end
  -- Drop overlapping key repeats; never queue a close of an unintended successor.
  local lock_path = (os.getenv('TMPDIR') or '/tmp') .. '/dotfiles-wm-close-' .. uv.os_get_passwd().uid .. '.lock'
  local lock <close> = assert(io.open(lock_path, 'a'))
  if not lfs.lock(lock, 'w') then return end
  M.close(api)
end)
if not ok then io.stderr:write('OmniWM close: ', tostring(err), '\n'); os.exit(1) end
