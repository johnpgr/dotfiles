-- smart-splits's plugin/ scripts fail in headless mode (/dev/fd/2 not available).
if #vim.api.nvim_list_uis() > 0 then
  vim.pack.add({ 'https://github.com/mrjones2014/smart-splits.nvim' })

  require('smart-splits').setup({
    at_edge = 'stop',
    multiplexer_integration = 'tmux',
  })
end
