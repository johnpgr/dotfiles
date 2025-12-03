-- Treesitter

return {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
        ---@diagnostic disable-next-line: missing-fields
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                "go",
                "lua",
                "python",
                "rust",
                "tsx",
                "javascript",
                "typescript",
                "vimdoc",
                "vim",
                "v",
                "markdown",
                "kotlin",
            },
            auto_install = true,
            highlight = {
                enable = true,
                disable = function(_, buf)
                    local max_filesize = 1024 * 1024
                    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
                    if ok and stats and stats.size > max_filesize then
                        return true
                    end
                end,
            },
            indent = { enable = true },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "vv",
                    node_incremental = "vv",
                },
            },
        })

        -- local ts_start = vim.treesitter.start
        -- if not vim.g.treesitter_enabled then
        --     ---@diagnostic disable-next-line: duplicate-set-field
        --     vim.treesitter.start = function(bufnr, lang)
        --         bufnr = bufnr or vim.api.nvim_get_current_buf()
        --         local bufname = vim.api.nvim_buf_get_name(bufnr)
        --
        --         if bufname == "" then
        --             return ts_start(bufnr, lang)
        --         end
        --
        --         if lang == "markdown" then
        --             return ts_start(bufnr, lang)
        --         end
        --     end
        -- end
    end,
}
