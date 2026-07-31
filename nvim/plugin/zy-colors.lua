vim.pack.add({
	"https://github.com/oonamo/ef-themes.nvim",
    "https://github.com/Mofiqul/vscode.nvim",
    "https://github.com/ishan9299/nvim-solarized-lua",
})

---@diagnostic disable-next-line: missing-fields
require("ef-themes").setup({
	light = "ef-tritanopia-light",
	dark = "ef-dream",
})

vim.cmd [[
    colorscheme solarized-flat
    hi! link EndOfBuffer WinSeparator
]]
