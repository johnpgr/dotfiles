vim.pack.add({
    "https://github.com/nvim-treesitter/nvim-treesitter",
})

if vim.fn.executable("tree-sitter") == 1 then
    require("nvim-treesitter").install({ "embedded_template" })
else
    vim.notify(
        "ECR Treesitter support needs the tree-sitter CLI (brew install tree-sitter-cli)",
        vim.log.levels.WARN
    )
end

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

-- Keep ECR's parser name so the queries in queries/ecr can inject Crystal.
-- The parser is installed asynchronously above, so only register it once the
-- compiled library exists.
local embedded_template_parser = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser", "embedded_template.so")
if vim.uv.fs_stat(embedded_template_parser) then
    vim.treesitter.language.add("ecr", {
        path = embedded_template_parser,
        symbol_name = "embedded_template",
    })
end
