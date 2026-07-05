vim.pack.add({ 'https://github.com/lewis6991/gitsigns.nvim' })

require('gitsigns').setup({
  attach_to_untracked = true,
  preview_config = {
    border = 'single',
    focusable = false,
  },
})
