vim.pack.add({ 'https://github.com/sindrets/diffview.nvim' })

require('diffview').setup({
  view = {
    merge_tool = {
      layout = 'diff3_mixed',
      disable_diagnostics = true,
      winbar_info = true,
    },
  },
})

vim.keymap.set('n', '<leader>gD', ':DiffviewOpen ', { desc = 'Git DiffView' })
vim.keymap.set('n', '<leader>gh', function()
  vim.cmd('DiffviewFileHistory ' .. vim.fn.expand('%'))
end, { desc = 'Git file history (Current)' })
vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>', { desc = 'Git file history (All)' })
