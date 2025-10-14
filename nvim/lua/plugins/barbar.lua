return {
    "romgrk/barbar.nvim",
    enabled = false,
    event = { "BufRead", "BufNewFile" },
    init = function()
        vim.g.barbar_auto_setup = false
    end,
    opts = {
        minimum_padding = 4,
        -- auto_hide = 0,
        -- hide = {
        --     current = true,   -- Hide the current buffer
        --     visible = true,   -- Hide visible (active) buffers
        --     inactive = true,  -- Hide inactive (hidden) buffers
        --     alternate = true, -- Hide alternate buffers
        -- },
        icons = {
            separator = { left = "", right = "" },
            separator_at_end = false,
            pinned = {
                button = "",
                filename = true,
                extension = true,
                separator = { left = "", right = "" },
                separator_at_end = false,
            },
        },
    },
    keys = {
        { "<leader>`", "<cmd>BufferPin<cr>", desc = "Pin a buffer" },
        { "<F1>", "<cmd>BufferGoto 1<cr>", desc = "Goto buffer 1" },
        { "<F2>", "<cmd>BufferGoto 2<cr>", desc = "Goto buffer 2" },
        { "<F3>", "<cmd>BufferGoto 3<cr>", desc = "Goto buffer 3" },
        { "<F4>", "<cmd>BufferGoto 4<cr>", desc = "Goto buffer 4" },
        { "<F5>", "<cmd>BufferGoto 5<cr>", desc = "Goto buffer 5" },
        { "<F6>", "<cmd>BufferGoto 6<cr>", desc = "Goto buffer 6" },
        { "<F7>", "<cmd>BufferGoto 7<cr>", desc = "Goto buffer 7" },
        { "<F8>", "<cmd>BufferGoto 8<cr>", desc = "Goto buffer 8" },
        { "<F9>", "<cmd>BufferGoto 9<cr>", desc = "Goto buffer 9" },
        { "<F10>", "<cmd>BufferGoto 10<cr>", desc = "Goto buffer 10" },
        { "<F11>", "<cmd>BufferGoto 11<cr>", desc = "Goto buffer 11" },
        { "<F12>", "<cmd>BufferGoto 12<cr>", desc = "Goto buffer 12" },
        { "<Tab>", "<cmd>BufferNext<cr>", desc = "Goto next buffer", mode = "n" },
        { "<S-Tab>", "<cmd>BufferPrevious<cr>", desc = "Goto previous buffer", mode = "n" },
    },
}
