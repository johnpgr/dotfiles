-- Telescope plugins
local utils = require("utils")

return {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
        {
            "<leader>sc",
            function()
                require("telescope.builtin").colorscheme()
            end,
            desc = "Search colorscheme",
        },
        {
            "<leader>se",
            function()
                require("telescope").extensions.env.env()
            end,
            desc = "Search environment variables",
        },
        {
            "<leader>sw",
            function()
                require("telescope.builtin").grep_string()
            end,
            desc = "Search word under cursor",
        },
        {
            "<leader>sh",
            function()
                require("telescope.builtin").help_tags()
            end,
            desc = "Search help",
        },
        {
            "<leader>sH",
            function()
                require("telescope.builtin").highlights()
            end,
            desc = "Search highlight group",
        },
        {
            "<leader>sd",
            function()
                require("utils").live_multi_grep({
                    cwd = require("telescope.utils").buffer_dir(),
                })
            end,
            desc = "Search current directory",
        },
        {
            "<leader>sf",
            function()
                require("telescope.builtin").find_files({ cwd = require("telescope.utils").buffer_dir() })
            end,
            desc = "Search file",
        },
        {
            "<leader>sp",
            function()
                require("telescope.builtin").find_files({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy") })
            end,
            desc = "Search file in plugins",
        },
        {
            "<leader>/",
            function()
                require("utils").live_multi_grep()
            end,
            desc = "Search workspace",
        },
        {
            "<leader><space>",
            function()
                require("telescope.builtin").find_files()
            end,
            desc = "Find file in workspace",
        },
        {
            "<leader>so",
            function()
                require("telescope.builtin").vim_options()
            end,
            desc = "Search option",
        },
        {
            "<leader>fR",
            function()
                require("telescope.builtin").oldfiles()
            end,
            desc = "Recent files",
        },
        {
            "<leader>fn",
            function()
                require("telescope.builtin").find_files({ path = vim.fn.stdpath("config") })
            end,
            desc = "Browse .config/nvim",
        },
        {
            "<leader>fp",
            function()
                require("telescope.builtin").find_files({
                    path = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
                })
            end,
            desc = "Find file in plugins",
        },
        {
            "<leader>fr",
            function()
                require("telescope.builtin").oldfiles({
                    only_cwd = true,
                })
            end,
            desc = "Recent files in workspace",
        },
        { "<leader>sb", utils.fuzzy_find_current_buffer, desc = "Search buffer" },
        {
            "<leader>ll",
            function()
                require("telescope.builtin").diagnostics({ path_display = { "filename_first" } })
            end,
            desc = "Diagnostic List",
        },
        {
            "<leader>sB",
            function()
                require("telescope.builtin").live_grep({ grep_open_files = true })
            end,
            desc = "Search buffer",
        },
        {
            "<leader>,",
            function()
                require("telescope.builtin").buffers({ only_cwd = true })
            end,
            desc = "Switch workspace buffers",
        },
        {
            "<leader><",
            function()
                require("telescope.builtin").buffers({})
            end,
            desc = "Switch buffers",
        },
        {
            "<leader>'",
            function()
                require("telescope.builtin").resume()
            end,
            desc = "Resume last search",
        },
        {
            "<leader>is",
            function()
                require("telescope.builtin").symbols()
            end,
            desc = "Symbols",
        },
        {
            "<leader>ss",
            function()
                require("telescope.builtin").spell_suggest()
            end,
            desc = "Search spelling suggestion",
        },
        {
            "<leader>st",
            function()
                require("telescope.builtin").builtin()
            end,
            desc = "Telescope builtin pickers",
        },
        {
            "<leader>glg",
            function()
                require("telescope").extensions.gh.gist()
            end,
            desc = "List gists",
        },
        {
            "<leader>gli",
            function()
                require("telescope").extensions.gh.issues()
            end,
            desc = "List issues",
        },
        {
            "<leader>glp",
            function()
                require("telescope").extensions.gh.pull_request()
            end,
            desc = "List pull requests",
        },
        {
            "grr",
            function()
                require("telescope.builtin").lsp_references()
            end,
            desc = "LSP References",
        },
        {
            "grt",
            function()
                require("telescope.builtin").lsp_type_definitions()
            end,
            desc = "LSP References",
        },
        {
            "grt",
            function()
                require("telescope.builtin").lsp_implementations()
            end,
            desc = "LSP References",
        },
        { "<leader>cp" },
    },
    dependencies = {
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
        },
        {
            "nvim-telescope/telescope-ui-select.nvim",
        },
        {
            "nvim-telescope/telescope-symbols.nvim",
        },
        {
            "nvim-telescope/telescope-github.nvim",
        },
        { "LinArcX/telescope-env.nvim" },
    },
    config = function()
        require("telescope").setup({
            defaults = {
                sorting_strategy = "ascending",
                layout_strategy = "flex",
                borderchars = { "", "", "", "", "", "", "", "" },
                layout_config = {
                    width = 400,
                    height = 100,
                    prompt_position = "top",
                    preview_cutoff = 40,
                    flip_columns = 120,
                },
                mappings = {
                    i = {
                        ["<C-q>"] = function(bufnr)
                            require("telescope.actions").send_to_qflist(bufnr)
                            vim.cmd("copen")
                        end,
                        ["<Esc>"] = require("telescope.actions").close,
                    },
                },
            },
            extensions = {
                fzf = {},
                ["ui-select"] = {
                    require("telescope.themes").get_ivy({
                        previewer = false,
                        borderchars = { " ", " ", " ", " ", " ", " ", " ", " " },
                        layout_config = {
                            height = 12,
                        },
                        results_title = false,
                    }),
                },
            },
            pickers = {
                buffers = {
                    mappings = {
                        i = {
                            ["<C-d>"] = require("telescope.actions").delete_buffer,
                        },
                    },
                },
                highlights = {
                    preview = true,
                },
                colorscheme = {
                    previewer = false,
                    enable_preview = true,
                    mappings = {
                        n = {
                            ["<CR>"] = function(bufnr)
                                local actions = require("telescope.actions")
                                local action_state = require("telescope.actions.state")
                                local selection = action_state.get_selected_entry()
                                local colors_selected = selection.value

                                require("colorscheme").persist_colorscheme(colors_selected)
                                actions.close(bufnr)
                                vim.cmd("colorscheme " .. colors_selected)
                            end,
                        },
                        i = {
                            ["<CR>"] = function(bufnr)
                                local actions = require("telescope.actions")
                                local action_state = require("telescope.actions.state")
                                local selection = action_state.get_selected_entry()
                                local colors_selected = selection.value

                                require("colorscheme").persist_colorscheme(colors_selected)
                                actions.close(bufnr)
                                vim.cmd("colorscheme " .. colors_selected)
                            end,
                        },
                    },
                },
            },
        })

        require("telescope").load_extension("ui-select")
        require("telescope").load_extension("fzf")
        require("telescope").load_extension("gh")
        require("telescope").load_extension("env")
    end,
}
