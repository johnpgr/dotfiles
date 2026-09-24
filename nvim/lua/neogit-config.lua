local term = vim.env.TERM
local is_kitty = term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"

vim.pack.add({
    "https://github.com/NeogitOrg/neogit",
    "https://github.com/sindrets/diffview.nvim",
})

require("neogit").setup({
    graph_style = is_kitty and "kitty" or "ascii",
    commit_editor = {
        kind = "vsplit",
        show_staged_diff = false,
    },
    console_timeout = 5000,
    auto_show_console = false,
    integrations = {
        diffview = true,
        mini_pick = false,
        telescope = false,
        fzf_lua = false,
        snacks = false,
    },
})

local map = vim.keymap.set
local function open_status()
    require("neogit").open({ kind = "split" })
end

map("n", "<M-g>", open_status, { desc = "Git status" })
map("n", "<leader>gg", open_status, { desc = "Git status" })
map("n", "<leader>gc", function()
    require("neogit.buffers.commit_view").new("HEAD"):open("replace")
end, { desc = "Git commit" })
map("n", "<leader>gb", "<cmd>Neogit branch<cr>", { desc = "Git branch" })
map("n", "<leader>gL", "<cmd>NeogitLogCurrent<cr>", { desc = "Git log" })
