return {
    "juniorsundar/refer.nvim",
    config = function()
        require("refer").setup()
    end,
    keys = {
        {
            ":",
            "<cmd>Refer Commands<cr>",
            desc = "commands"
        },
        {
            "<M-x>",
            "<cmd>Refer Commands<cr>",
            desc = "commands"
        },
        {
            "<leader><space>",
            "<cmd>Refer Files<cr>",
            desc = "Find Files"
        },
        {
            "<leader>fr",
            "<cmd>Refer OldFiles<cr>",
            desc = "Old files"
        },
        {
            "<leader>/",
            "<cmd>Refer Grep<cr>",
            desc = "Grep"
        },
        {
            "gd",
            "<cmd>Refer Definitions<cr>",
            desc = "Go to definitions"
        },
        {
            "gr",
            "<cmd>Refer References<cr>",
            desc = "Go to references"
        },
    }
}
