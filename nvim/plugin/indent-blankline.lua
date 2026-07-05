vim.pack.add({ 'https://github.com/lukas-reineke/indent-blankline.nvim' })

require('ibl').setup({
  enabled = false,
  indent = { char = '│' },
  scope = { enabled = false },
})

vim.keymap.set('n', '<leader>ig', '<cmd>IBLToggle<cr>', { desc = 'Indent Guides' })
