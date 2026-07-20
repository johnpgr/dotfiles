vim.pack.add({
	"https://github.com/oonamo/ef-themes.nvim",
})

---@diagnostic disable-next-line: missing-fields
require("ef-themes").setup({
	light = "ef-tritanopia-light",
	dark = "ef-cherie",
})

vim.cmd.colorscheme("ef-theme")
