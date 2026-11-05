vim.pack.add({
    "https://github.com/nvim-mini/mini.align",
    "https://github.com/nvim-mini/mini.bufremove",
    "https://github.com/nvim-mini/mini.icons",
})

require("mini.icons").setup({
    lsp = {
        ["function"] = { glyph = "󰆧" },
    },
})

MiniIcons.mock_nvim_web_devicons()

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
