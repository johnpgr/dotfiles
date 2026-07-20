if #vim.api.nvim_list_uis() > 0 then
  vim.pack.add({ 'https://github.com/aserowy/tmux.nvim' })

  require('tmux').setup()
end
