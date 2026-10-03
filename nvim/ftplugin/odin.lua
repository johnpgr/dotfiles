vim.keymap.set("x", "<leader>!", ":!odinfmt -stdin ", {
	buffer = true,
	desc = "Filter selection through odinfmt",
})
