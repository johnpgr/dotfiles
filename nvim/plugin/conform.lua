vim.pack.add({ 'https://github.com/stevearc/conform.nvim' })

require('conform').setup({
  formatters_by_ft = {
    lua = { 'stylua', lsp_format = 'fallback' },
    python = { 'isort', 'black', lsp_format = 'fallback' },
    rust = { 'rustfmt', lsp_format = 'fallback' },
    html = { 'oxfmt', lsp_format = 'fallback' },
    css = { 'oxfmt', lsp_format = 'fallback' },
    json = { 'oxfmt', lsp_format = 'fallback' },
    javascript = { 'oxfmt', lsp_format = 'fallback' },
    javascriptreact = { 'oxfmt', lsp_format = 'fallback' },
    typescript = { 'oxfmt', lsp_format = 'fallback' },
    typescriptreact = { 'oxfmt', lsp_format = 'fallback' },
    astro = { 'oxfmt', lsp_format = 'fallback' },
    c = { 'clang-format', stop_after_first = true, lsp_format = 'fallback' },
    cpp = { 'clang-format', stop_after_first = true, lsp_format = 'fallback' },
    odin = { lsp_format = 'fallback' },
    zig = { lsp_format = 'fallback' },
  },
})

vim.keymap.set('n', '<leader>lf', function()
  require('conform').format({ async = true })
end, { desc = 'Format buffer' })
