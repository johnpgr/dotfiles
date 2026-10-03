-- The trailing space and missing <CR> leave the command line open so extra flags such as --lines can be appended.
vim.keymap.set("x", "<leader>!", ":!clang-format --assume-filename=% ", {
	buffer = true,
	desc = "Filter selection through clang-format",
})
