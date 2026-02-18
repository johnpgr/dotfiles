-- CMDLINE AUTOCOMPLETION (see :h cmdline-autocompletion)

-- Core: show a popup menu of suggestions as you type on : / ?
vim.api.nvim_create_autocmd("CmdlineChanged", {
  pattern = {":", "/", "?"},
  callback = function()
    vim.fn.wildtrigger()
  end,
})

vim.opt.wildmode = "noselect:lastused,full"
vim.opt.wildoptions = "pum"

-- Keep <Up>/<Down> for history when the wildmenu is not active
vim.keymap.set("c", "<Up>", function()
  return vim.fn.wildmenumode() == 1 and [[<C-E><Up>]] or [[<Up>]]
end, { expr = true })

vim.keymap.set("c", "<Down>", function()
  return vim.fn.wildmenumode() == 1 and [[<C-E><Down>]] or [[<Down>]]
end, { expr = true })

-- Smaller popup during search (8 lines), restored on leave
vim.api.nvim_create_autocmd("CmdlineEnter", {
  pattern = {"/", "?"},
  callback = function()
    vim.opt.pumheight = 8
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  pattern = {"/", "?"},
  callback = function()
    vim.opt.pumheight = vim.go.pumheight
  end,
})
