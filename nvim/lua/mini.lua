vim.pack.add({
    "https://github.com/nvim-mini/mini.align",
    "https://github.com/nvim-mini/mini.bufremove",
})

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
