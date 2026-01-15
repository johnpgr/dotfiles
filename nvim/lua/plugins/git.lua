-- Git plugins
return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        keys = {
            {
                "]h",
                function()
                    -- if vim.wo.diff then
                    --     vim.cmd.normal({ "]c", bang = true })
                    -- else
                    vim.cmd("Gitsigns next_hunk")
                    vim.cmd("Gitsigns preview_hunk")
                    -- end
                end,
                { desc = "Next hunk" },
            },
            {
                "[h",
                function()
                    -- if vim.wo.diff then
                    --     vim.cmd.normal({ "[c", bang = true })
                    -- else
                    vim.cmd("Gitsigns prev_hunk")
                    vim.cmd("Gitsigns preview_hunk")
                    -- end
                end,
                { desc = "Previous hunk" },
            },

            { "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", desc = "Stage hunk" },
            { "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", desc = "Reset hunk" },
            { "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", desc = "Undo stage hunk" },
            { "<leader>gB", "<cmd>Gitsigns blame<cr>", desc = "Git blame" },
            { "<leader>gd", "<cmd>Gitsigns diffthis<cr>", desc = "Git diff" },
            { "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", desc = "Toggle blame inline" },
            { "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", desc = "Preview hunk" },
            { "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", desc = "Preview hunk inline" },
            { "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", desc = "Toggle word diff" },
        },
        config = function()
            require("gitsigns").setup({
                attach_to_untracked = true,
                preview_config = {
                    border = "single",
                },
            })
        end,
    },
    {
        "NeogitOrg/neogit",
        cmd = "Neogit",
        keys = {
            {
                "<M-g>",
                function()
                    require("neogit").open({ kind = "replace" })
                end,
                desc = "Git status",
            },
            {
                "<leader>gg",
                function()
                    require("neogit").open({ kind = "replace" })
                end,
                desc = "Git status",
            },
            {
                "<leader>gc",
                function()
                    require("neogit.buffers.commit_view").new("HEAD"):open("replace")
                end,
                desc = "Git commit",
            },
            {
                "<leader>gb",
                "<cmd>Neogit branch<cr>",
                desc = "Git branch",
            },
            {
                "<leader>gL",
                "<cmd>NeogitLogCurrent<cr>",
                desc = "Git log",
            },
        },
        config = function()
            require("neogit").setup({
                graph_style = require("utils").is_kitty and "kitty" or "ascii",
                commit_editor = {
                    kind = "vsplit",
                    show_staged_diff = false,
                },
                console_timeout = 5000,
                auto_show_console = false,
            })
        end,
    },
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewFileHistory" },
        keys = {
            { "<leader>gD", ":DiffviewOpen ", desc = "Git DiffView" },
            {
                "<leader>gh",
                function()
                    vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
                end,
                desc = "Git file history (Current)",
            },
            { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git file history (All)" },
        },
        config = function()
            require("diffview").setup({
                view = {
                    merge_tool = {
                        layout = "diff3_mixed",
                        disable_diagnostics = true, -- Temporarily disable diagnostics for diff buffers while in the view.
                        winbar_info = true, -- See |diffview-config-view.x.winbar_info|
                    },
                },
            })
        end,
    },
}
