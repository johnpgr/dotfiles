vim.pack.add({
    "https://github.com/nvim-treesitter/nvim-treesitter",
})

vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = function()
        require("nvim-treesitter.parsers").crystal = {
            install_info = {
                url = "https://github.com/crystal-lang-tools/tree-sitter-crystal",
                queries = "queries/nvim",
            },
        }
    end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        for name in pairs(vim.api.nvim_get_hl(0, {})) do
            if name:sub(1, 1) == "@" and not name:match("^@lsp%.") then
                local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
                if highlight.bold or (highlight.cterm and highlight.cterm.bold) then
                    highlight.bold = false
                    if highlight.cterm then
                        highlight.cterm.bold = false
                    end
                    vim.api.nvim_set_hl(0, name, highlight)
                end
            end
        end
    end,
})

vim.filetype.add({ extension = { ecr = "ecr" } })

-- Reuses the embedded_template grammar under its own language name so that
-- ECR can inject Crystal, while ERB and EJS keep their Ruby and JavaScript
-- injections.
vim.treesitter.language.add("ecr", {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser", "embedded_template.so"),
    symbol_name = "embedded_template",
})
