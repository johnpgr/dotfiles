-- LSP floating window config
local lsp_floating_preview_original = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = "single"
    opts.max_width = opts.max_width or 100
    return lsp_floating_preview_original(contents, syntax, opts, ...)
end

-- Diagnostic config
vim.diagnostic.config({
    severity_sort = true,
    float = { border = "single", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    -- virtual_lines = true,
    -- virtual_text = {
    -- 	source = "if_many",
    -- 	spacing = 2,
    -- 	format = function(diagnostic)
    -- 		return diagnostic.message
    -- 	end,
    -- },
})

-- Remove LSP semantic tokens
vim.lsp.semantic_tokens.enable(false)

-- LSP plugins
return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.lsp.enable({
                "lua_ls",
                "vtsls",
                "clangd",
                "html",
                "cssls",
                "jsonls",
                "basedpyright",
                "zls",
                -- "tailwindcss",
                "dartls",
                "glsl_analyzer",
                "kotlin_language_server",
                "kotlin_lsp",
                "astro",
                "rust_analyzer",
                "sqlls",
                "oxlint",
                "ols",
            })
        end,
    },
    {
        "mason-org/mason.nvim",
        event = "BufReadPre",
        cmd = "Mason",
        build = ":MasonUpdate",
        config = function()
            require("mason").setup({})
        end,
    },
    {
        "folke/lazydev.nvim",
        dependencies = { "DrKJeff16/wezterm-types" },
        ft = "lua",
        config = function()
            require("lazydev").setup({
                library = {
                    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                    { path = "wezterm-types", mods = { "wezterm" } },
                },
            })
        end,
    },
    {
        ft = { "java" },
        "mfussenegger/nvim-jdtls",
    },
    {
        "yioneko/nvim-vtsls",
        ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
        config = function()
            require("lspconfig.configs").vtsls = require("vtsls").lspconfig

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if not client or client.name ~= "vtsls" then
                        return
                    end

                    local items = {
                        {
                            name = "restart_tsserver",
                            desc = "Does not restart vtsls itself, but restarts the underlying tsserver.",
                        },
                        {
                            name = "open_tsserver_log",
                            desc = "It will open prompt if logging has not been enabled.",
                        },
                        { name = "reload_projects", desc = "Reload tsserver projects for the workspace." },
                        {
                            name = "select_ts_version",
                            desc = "Select version of ts either from workspace or global.",
                        },
                        { name = "goto_project_config", desc = "Open tsconfig.json." },
                        { name = "goto_source_definition", desc = "Go to the source definition instead of typings." },
                        { name = "file_references", desc = "Show references of the current file." },
                        {
                            name = "rename_file",
                            desc = "Rename the current file and update all the related paths in the project.",
                        },
                        { name = "organize_imports", desc = "Organize imports in the current file." },
                        { name = "sort_imports", desc = "Sort imports in the current file." },
                        { name = "remove_unused_imports", desc = "Remove unused imports from the current file." },
                        { name = "fix_all", desc = "Apply all available code fixes." },
                        { name = "remove_unused", desc = "Remove unused variables and symbols." },
                        { name = "add_missing_imports", desc = "Add missing imports for unresolved symbols." },
                        { name = "source_actions", desc = "Pick applicable source actions (same as above)" },
                    }

                    vim.keymap.set("n", "<leader>lt", function()
                        vim.ui.select(items, {
                            prompt = "TypeScript LSP actions",
                            format_item = function(entry)
                                return string.format("%-24s %s", entry.name, entry.desc or "")
                            end,
                        }, function(selection)
                            if not selection or not selection.name then
                                return
                            end

                            vim.cmd("VtsExec " .. selection.name)
                        end)
                    end, { desc = "Typescript LSP actions (vtsls)", buffer = args.buf })
                end,
            })
        end,
    },
}
