vim.keymap.set("x", "<leader>!", ":!rustfmt --edition 2024 ", {
	buffer = true,
	desc = "Filter selection through rustfmt",
})
