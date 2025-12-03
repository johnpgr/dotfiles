-- WhichKey.nvim
return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
        local wk = require("which-key")
        wk.setup({
            icons = { mappings = false },
            win = {
                border = "single",
                height = { min = 4, max = 10 },
            },
        })
        wk.add({
            { "<leader>f", group = "file" },
            { "<leader>s", group = "search" },
            { "<leader>g", group = "git" },
            { "<leader>gl", group = "list" },
            { "<leader>h", group = "hunk" },
            { "<leader>c", group = "copilot" },
            { "<leader>l", group = "lsp" },
            { "<leader>t", group = "toggle" },
            { "<leader>i", group = "insert" },
            { "<leader>d", group = "db" },
            { "<leader>a", group = "ai" },
        })
    end,
}
