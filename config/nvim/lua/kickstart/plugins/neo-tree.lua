-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

vim.keymap.set('n', '<leader>e', '<Cmd>Neotree toggle filesystem left<CR>', { desc = 'Toggle file [E]xplorer', silent = true })

require('neo-tree').setup {
  window = { position = 'left', width = 32 },
  filesystem = {
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}
