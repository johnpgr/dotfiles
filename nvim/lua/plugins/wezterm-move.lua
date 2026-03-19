return {
    "letieu/wezterm-move.nvim",
    lazy = true,
    keys = {
        {
            "<C-h>",
            function()
                require("wezterm-move").move("h")
            end,
            desc = "Move left",
        },
        {
            "<C-j>",
            function()
                require("wezterm-move").move("j")
            end,
            desc = "Move down",
        },
        {
            "<C-k>",
            function()
                require("wezterm-move").move("k")
            end,
            desc = "Move up",
        },
        {
            "<C-l>",
            function()
                require("wezterm-move").move("l")
            end,
            desc = "Move right",
        },
    },
}
