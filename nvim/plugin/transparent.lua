vim.pack.add({ 'https://github.com/xiyaowong/transparent.nvim' })

require('transparent').setup({
  exclude_groups = {
    'CursorLine',
    'CursorLineNr',
    'StatusLine',
    'StatusLineNC',
  },
  extra_groups = {
    'VertSplit',
    'NormalFloat',
    'SignColumn',
    'FoldColumn',
    'WinBar',
    'WinBarNC',
    'Directory',
    'NeoTreeNormal',
    'NeoTreeNormalNC',
    'NeoTreeEndOfBuffer',
    'WhichKeyTitle',
    'FloatBorder',
    'SpecialKey',
    'BlinkCmpDoc',
    'BlinkCmpDocBorder',
  },
})
