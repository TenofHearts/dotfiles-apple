-- Shared settings stay in Git; local monitor settings and composed files do not.
local M = {}
local source = assert(require('luv').fs_realpath(debug.getinfo(1, 'S').source:sub(2)))
local root = assert(source:match('^(.*)/config/sketchybar/plugins/wm/config.lua$'))
local keys = {'monitorBarOverrides', 'monitorDwindleOverrides', 'monitorGapOverrides',
  'monitorNiriOverrides', 'monitorOrientationOverrides'}
local allowed = {}
for _, key in ipairs(keys) do allowed[key] = true end
local function omniwm_assignments(shared, local_settings)
  local remaining, assignments, in_assignments, seen = {}, {}, false, false
  for line in (local_settings .. '\n'):gmatch('(.-)\n') do
    if line:match('^%s*%[') then
      in_assignments = line:match('^%s*%[workspace%-monitor%-assignments%]%s*$') ~= nil
      if in_assignments then
        assert(not seen, 'Duplicate workspace-monitor-assignments section'); seen = true
      else remaining[#remaining+1] = line end
    elseif in_assignments then
      if not line:match('^%s*$') and not line:match('^%s*#') then
        local name, role = line:match('^%s*"([^"]+)"%s*=%s*"([%w]+)"%s*$')
        assert(name and (role == 'main' or role == 'secondary' or role == 'tertiary'),
          'Expected "workspace" = "main", "secondary", or "tertiary"')
        assert(not assignments[name], 'Duplicate workspace monitor assignment: ' .. name)
        assignments[name] = role
      end
    else remaining[#remaining+1] = line end
  end
  local rendered, name, workspace_section, assignment_section, applied = {}, nil, false, false, {}
  for line in (shared .. '\n'):gmatch('(.-)\n') do
    local output = line
    if line:match('^%s*%[%[workspaces%]%]%s*$') then
      name, workspace_section, assignment_section = nil, true, false
    elseif line:match('^%s*%[workspaces%.monitorAssignment%]%s*$') then
      workspace_section, assignment_section = false, true
    elseif line:match('^%s*%[') then
      workspace_section, assignment_section = false, false
    end
    if workspace_section then name = line:match('^name%s*=%s*"([^"]+)"%s*$') or name end
    if assignment_section and assignments[name] and line:match('^type%s*=') then
      assert(not applied[name], 'Duplicate shared workspace monitor assignment: ' .. name)
      output = 'type = "' .. assignments[name] .. '"'; applied[name] = true
    end
    rendered[#rendered+1] = output
  end
  for workspace in pairs(assignments) do assert(applied[workspace], 'Unknown workspace assignment: ' .. workspace) end
  return table.concat(rendered, '\n'), table.concat(remaining, '\n')
end
function M.read(path)
  local file = assert(io.open(path, 'r'))
  local content = file:read('*a'); file:close(); return content
end
function M.write(path, content)
  local file = io.open(path, 'r')
  if file then
    local previous = file:read('*a'); file:close()
    if previous == content then return false end
  end
  -- Exclusive creation avoids collisions between the installer and bar process.
  local uv = require('luv')
  local temporary = path .. '.tmp-' .. uv.os_getpid()
  local fd = assert(uv.fs_open(temporary, 'wx', 384))
  local ok, err = pcall(function()
    assert(uv.fs_write(fd, content, 0)); assert(uv.fs_fsync(fd))
  end)
  uv.fs_close(fd)
  if not ok then uv.fs_unlink(temporary); error(err) end
  assert(uv.fs_rename(temporary, path))
  return true
end
function M.paths(backend, directory)
  directory = directory or root .. '/config/' .. backend
  local stem = backend == 'omniwm' and 'settings' or 'aerospace'
  return directory .. '/' .. stem .. '.shared.toml', directory .. '/monitors.local.toml',
    directory .. '/' .. stem .. '.toml'
end
function M.compose(backend, shared, local_settings)
  local header = '# Generated from the shared config and monitors.local.toml; edit those files.\n'
  if backend == 'omniwm' then
    shared, local_settings = omniwm_assignments(shared, local_settings)
    local prefix, suffix, found, in_table = {}, {}, {}, false
    for line in (local_settings .. '\n'):gmatch('(.-)\n') do
      local table_key = line:match('^%s*%[%[?([%w_]+)')
      if table_key then
        assert(allowed[table_key], 'Only monitor override tables belong in monitors.local.toml')
        in_table, found[table_key] = true, true
      end
      if not in_table then
        local key = line:match('^%s*([%w_]+)%s*=')
        if key then assert(allowed[key], 'Only monitor overrides belong in monitors.local.toml'); found[key] = true end
      end
      local target = in_table and suffix or prefix
      target[#target+1] = line
    end
    for _, key in ipairs(keys) do
      local count
      shared, count = shared:gsub('\n' .. key .. '%s*=%s*%[%][^\n]*', '')
      assert(count == 1, 'Expected one empty ' .. key .. ' in shared settings')
      if not found[key] then prefix[#prefix+1] = key .. ' = []' end
    end
    return header .. table.concat(prefix, '\n') .. '\n' .. shared .. '\n' .. table.concat(suffix, '\n')
  end
  assert(backend == 'aerospace', 'Unknown window manager')
  local section, top, assignments = nil, nil, {}
  for line in (local_settings .. '\n'):gmatch('(.-)\n') do
    local table_name = line:match('^%s*%[([^%]]+)%]%s*$')
    if table_name then
      assert(table_name == 'gaps' or table_name == 'workspace-to-monitor-force-assignment',
        'Only screen gaps and monitor assignments belong in monitors.local.toml')
      section = table_name
    elseif not line:match('^%s*$') and not line:match('^%s*#') then
      if section == 'gaps' then
        assert(line:match('^outer%.top%s*='), 'Only outer.top is a local gap setting')
        assert(not top, 'Duplicate local outer.top'); top = line
      else
        assert(section == 'workspace-to-monitor-force-assignment', 'Expected a local screen section')
        assignments[#assignments+1] = line
      end
    end
  end
  if top then
    local count
    shared, count = shared:gsub('outer%.top%s*=[^\n]*', function() return top end)
    assert(count == 1, 'Expected one shared outer.top')
  end
  if #assignments > 0 then
    assert(not shared:find('[workspace-to-monitor-force-assignment]', 1, true), 'Duplicate monitor assignments')
    shared = shared .. '\n[workspace-to-monitor-force-assignment]\n' .. table.concat(assignments, '\n') .. '\n'
  end
  return header .. shared
end
function M.generate(backend, directory)
  local shared, local_path, runtime = M.paths(backend, directory)
  local file = io.open(local_path, 'r')
  if file then file:close() else
    local defaults = '# Machine-specific screen settings; ignored by Git.\n'
    if backend == 'omniwm' then
      defaults = defaults .. '[workspace-monitor-assignments]\n'
      for workspace=7,9 do defaults = defaults .. ('"%d" = "secondary"\n'):format(workspace) end
    else
      defaults = defaults .. '[workspace-to-monitor-force-assignment]\n'
      for workspace=1,8 do defaults = defaults .. ('"%d" = "main"\n'):format(workspace) end
      defaults = defaults .. '"9" = ["secondary", "main"]\n'
    end
    M.write(local_path, defaults)
  end
  local changed = M.write(runtime, M.compose(backend, M.read(shared), M.read(local_path)))
  return runtime, changed
end
return M
