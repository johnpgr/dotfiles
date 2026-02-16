-- Formatter plugins
return {
    "stevearc/conform.nvim",
    event = "BufReadPost",
    cmd = { "ConformInfo" },
    config = function()
        require("conform").setup({
            formatters_by_ft = {
                lua = { "stylua", lsp_format = "fallback" },
                python = { "isort", "black", lsp_format = "fallback" },
                rust = { "rustfmt", lsp_format = "fallback" },
                html = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                css = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                json = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                javascript = { "oxfmt", lsp_format = "fallback" },
                javascriptreact = { "oxfmt", lsp_format = "fallback" },
                typescript = { "oxfmt", lsp_format = "fallback" },
                typescriptreact = { "oxfmt", lsp_format = "fallback" },
                astro = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                cpp = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
                odin = { lsp_format = "fallback" },
            },
        })
    end,
}
