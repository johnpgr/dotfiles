-- CodeCompanion plugin

return {
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
                adapters = {
                    acp = {
                        claude_code = function()
                            return require("codecompanion.adapters").extend("claude_code", {
                                env = {
                                    CLAUDE_CODE_OAUTH_TOKEN = "cmd:gpg --quiet --decrypt $HOME/.claude/token.txt.gpg",
                                },
                            })
                        end,
                        gemini_cli = function()
                            return require("codecompanion.adapters").extend("gemini_cli", {
                                defaults = {
                                    auth_method = "oauth-personal",
                                },
                                env = {
                                    GEMINI_API_KEY = "cmd:gpg --quiet --decrypt $HOME/.gemini/token.txt.gpg",
                                },
                            })
                        end,
                    },
                },
                strategies = {
                    chat = {
                        adapter = { name = "copilot", model = "gpt-5.1-codex" },
                    },
                    inline = {
                        adapter = { name = "copilot", model = "gpt-5.1-codex" },
                    },
                    cmd = {
                        adapter = { name = "copilot", model = "gpt-5.1-codex" },
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
