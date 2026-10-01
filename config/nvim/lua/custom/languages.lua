-- Language settings are kept separate from Kickstart's editor skeleton.
local M = {}
local clangd_cmd = { 'clangd', '--background-index', '--completion-style=detailed' }
-- Permit header discovery from the trusted Homebrew compilers only.
-- clangd still takes the actual compiler and flags from compile_commands.json.
local brew_prefix = vim.env.HOMEBREW_PREFIX
if brew_prefix and vim.fn.has 'macunix' == 1 then
  table.insert(clangd_cmd, '--query-driver=' .. brew_prefix .. '/bin/gcc-*,' .. brew_prefix .. '/bin/g++-*')
end

M.servers = {
  clangd = {
    cmd = clangd_cmd,
    filetypes = { 'c', 'cpp' },
  },
  pyright = {
    -- Prefer each project's uv-style .venv, including the Windows layout.
    before_init = function(_, config)
      if not config.root_dir then return end
      local executable = vim.fn.has 'win32' == 1 and 'Scripts/python.exe' or 'bin/python'
      local python = vim.fs.joinpath(config.root_dir, '.venv', executable)
      if vim.fn.executable(python) == 1 then
        config.settings = vim.tbl_deep_extend('force', config.settings or {}, { python = { pythonPath = python } })
      end
    end,
    settings = {
      python = { analysis = { typeCheckingMode = 'basic', diagnosticMode = 'openFilesOnly' } },
    },
  },
  rust_analyzer = {
    settings = {
      ['rust-analyzer'] = {
        check = { command = 'clippy' }, -- Run Clippy diagnostics when saving Rust files.
      },
    },
  },
}

return M
