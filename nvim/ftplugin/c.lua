vim.treesitter.start()

vim.keymap.set("x", "<leader>!", ":!clang-format --assume-filename=% ", {
	buffer = true,
	desc = "Filter selection through clang-format",
})
