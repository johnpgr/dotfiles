-- Neovide specific settings

vim.o.guifont = "BigBlueTerm437 Nerd Font:h14"
vim.g.neovide_floating_shadow = false
vim.g.neovide_position_animation_length = 0
vim.g.neovide_cursor_animation_length = 0.00
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_scroll_animation_far_lines = 0
vim.g.neovide_scroll_animation_length = 0.00

vim.keymap.set("n", "<C-=>", function()
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * 1.1
end, { desc = "Increase Neovide scale factor" })

vim.keymap.set("n", "<C-->", function()
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor / 1.1
end, { desc = "Decrease Neovide scale factor" })

vim.keymap.set("v", "<C-S-c>", "\"+y") -- Copy
vim.keymap.set("n", "<C-S-v>", "\"+P") -- Paste normal mode
vim.keymap.set("v", "<C-S-v>", "\"+P") -- Paste visual mode
vim.keymap.set("c", "<C-S-v>", "<C-R>+") -- Paste command mode
vim.keymap.set("i", "<C-S-v>", "<ESC>l\"+Pli") -- Paste insert mode

vim.api.nvim_set_keymap("", "<C-S-v>", "+p<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("!", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
