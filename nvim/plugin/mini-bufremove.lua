vim.pack.add({ 'https://github.com/nvim-mini/mini.bufremove' })

require('mini.bufremove').setup()

vim.keymap.set('n', '<leader>x', function()
  require('mini.bufremove').delete()
end, { desc = 'Delete buffer' })
