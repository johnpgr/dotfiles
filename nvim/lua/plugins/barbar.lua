return {
    'romgrk/barbar.nvim',
    init = function() vim.g.barbar_auto_setup = false end,
    opts = {
        minimum_padding = 4,
        auto_hide = 0,
        hide = {
            current = true,   -- Hide the current buffer
            visible = true,   -- Hide visible (active) buffers
            inactive = true,  -- Hide inactive (hidden) buffers
            alternate = true, -- Hide alternate buffers
        },
        icons = {
            pinned = {
                button = "",
                filename = true,
                extension = true,
                separator = { left = '', right = '' },
                separator_at_end = false,
            },
        },
    },
    keys = {
        { "<leader>`", "<cmd>BufferPin<cr>",           desc = "Pin a buffer" },
        { "<F1>",      "<cmd>BufferGotoPinned 1<cr>",  desc = "Goto buffer 1" },
        { "<F2>",      "<cmd>BufferGotoPinned 2<cr>",  desc = "Goto buffer 2" },
        { "<F3>",      "<cmd>BufferGotoPinned 3<cr>",  desc = "Goto buffer 3" },
        { "<F4>",      "<cmd>BufferGotoPinned 4<cr>",  desc = "Goto buffer 4" },
        { "<F5>",      "<cmd>BufferGotoPinned 5<cr>",  desc = "Goto buffer 5" },
        { "<F6>",      "<cmd>BufferGotoPinned 6<cr>",  desc = "Goto buffer 6" },
        { "<F7>",      "<cmd>BufferGotoPinned 7<cr>",  desc = "Goto buffer 7" },
        { "<F8>",      "<cmd>BufferGotoPinned 8<cr>",  desc = "Goto buffer 8" },
        { "<F9>",      "<cmd>BufferGotoPinned 9<cr>",  desc = "Goto buffer 9" },
        { "<F10>",     "<cmd>BufferGotoPinned 10<cr>", desc = "Goto buffer 10" },
        { "<F11>",     "<cmd>BufferGotoPinned 11<cr>", desc = "Goto buffer 11" },
        { "<F12>",     "<cmd>BufferGotoPinned 12<cr>", desc = "Goto buffer 12" },
    }
}
