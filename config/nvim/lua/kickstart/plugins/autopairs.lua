-- autopairs
-- https://github.com/windwp/nvim-autopairs

vim.pack.add { 'https://github.com/windwp/nvim-autopairs' }
-- Blink owns Enter for accepting completion; pair insertion needs no Enter mapping.
require('nvim-autopairs').setup { map_cr = false }
