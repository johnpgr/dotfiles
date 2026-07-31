if #vim.api.nvim_list_uis() > 0 then
  vim.pack.add({ 'https://github.com/aserowy/tmux.nvim' })

  require('tmux').setup({
      -- Keep navigation/resize only. copy_sync.enable + default sync_clipboard
      -- rewrites vim.g.clipboard to `tmux save-buffer`, so `p` / "+p paste the
      -- tmux buffer instead of the macOS clipboard (pbcopy/pbpaste).
      copy_sync = {
          enable = false,
      },
  })
end
