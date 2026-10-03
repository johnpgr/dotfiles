-- -q keeps black's "reformatted -" status text, which goes to stderr, out of the replaced lines.
vim.keymap.set("x", "<leader>!", ":!black -q --stdin-filename=% - ", {
	buffer = true,
	desc = "Filter selection through black",
})
