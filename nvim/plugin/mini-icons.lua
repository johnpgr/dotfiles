vim.pack.add({ 'https://github.com/nvim-mini/mini.icons' })

require('mini.icons').setup({
  lsp = {
    ['function'] = { glyph = '󰆧' },
  },
})

MiniIcons.mock_nvim_web_devicons()
