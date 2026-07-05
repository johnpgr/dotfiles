vim.pack.add({
  'https://github.com/L3MON4D3/LuaSnip',
  'https://github.com/rafamadriz/friendly-snippets',
  'https://github.com/xzbdmw/colorful-menu.nvim',
  {
    src = 'https://github.com/saghen/blink.cmp',
    version = 'v1.10.2',
  },
})

require('config.completion').setup()
