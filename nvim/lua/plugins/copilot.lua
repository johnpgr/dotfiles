-- Copilot plugins

return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    hide_during_completion = true,
                    debounce = 75,
                    trigger_on_accept = true,
                    keymap = {
                        accept = "<M-l>",
                        accept_word = false,
                        accept_line = false,
                        next = "<M-]>",
                        prev = "<M-[>",
                        dismiss = "<C-]>",
                    },
                },
            })
        end,
    },
    {
        "olimorris/codecompanion.nvim",
        version = "v17.33.0",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
        },
        cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
        keys = {
            { "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle chat" },
            { "<leader>ca", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Actions" },
            { "<leader>ci", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "Inline assistant" },
            {
                "<leader>cm",
                function()
                    require("copilot-scripts").commit_message("gpt-4.1")
                end,
                desc = "Commit message",
            },
            { "ga", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add to chat" },
        },
        config = function()
            require("codecompanion").setup({
                strategies = {
                    chat = {
                        adapter = { name = "copilot", model = "claude-opus-4.5" },
                    },
                    inline = {
                        adapter = { name = "copilot", model = "claude-opus-4.5" },
                    },
                    cmd = {
                        adapter = { name = "copilot", model = "claude-opus-4.5" },
                    },
                },
                display = {
                    chat = {
                        window = {
                            layout = "vertical",
                            width = 0.4,
                        },
                    },
                },
            })
        end,
    },
}
