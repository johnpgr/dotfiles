local function nav_hunk(direction)
    if vim.wo.diff then
        local key = direction == "next" and "]c" or "[c"
        vim.cmd.normal({ key, bang = true })
        return
    end

    local popup = require("gitsigns.popup")
    popup.close("hunk")

    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative ~= "" then
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_config(w).relative == "" then
                vim.api.nvim_set_current_win(w)
                break
            end
        end
    end

    local gitsigns = require("gitsigns")
    local bufnr = vim.api.nvim_get_current_buf()
    local hunks = gitsigns.get_hunks(bufnr) or {}
    if #hunks == 0 then
        return
    end

    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local target

    if direction == "next" then
        for _, h in ipairs(hunks) do
            if h.added.start > cur then
                target = h.added.start
                break
            end
        end
        if not target then
            target = hunks[1].added.start
        end
    else
        for i = #hunks, 1, -1 do
            if hunks[i].added.start < cur then
                target = hunks[i].added.start
                break
            end
        end
        if not target then
            target = hunks[#hunks].added.start
        end
    end

    target = math.max(1, math.min(target, vim.api.nvim_buf_line_count(bufnr)))
    vim.api.nvim_win_set_cursor(0, { target, 0 })

    vim.schedule(function()
        gitsigns.preview_hunk()
    end)
end

-- Git plugins
return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        keys = {
            {
                "]h",
                function()
                    nav_hunk("next")
                end,
                { desc = "Next hunk" },
            },
            {
                "[h",
                function()
                    nav_hunk("prev")
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
                    focusable = false,
                },
                signs = {
                    add = { text = "+" },
                    change = { text = "~" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                    untracked = { text = "+" },
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
