vim.pack.add({
    "https://github.com/nvim-mini/mini.align",
    "https://github.com/nvim-mini/mini.bufremove",
    "https://github.com/nvim-mini/mini.icons",
})

if vim.g.icons_enabled then
    require("mini.icons").setup({
        lsp = {
            ["function"] = { glyph = "󰆧" },
        },
    })
    require("mini.icons").mock_nvim_web_devicons()
end

require("mini.align").setup({
    mappings = {
        start = "ga",
        start_with_preview = "gA",
    },
})

require("mini.bufremove").setup()

vim.keymap.set("n", "<leader>x", function()
    require("mini.bufremove").delete()
end, { desc = "Delete buffer" })
