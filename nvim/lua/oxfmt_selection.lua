-- Called from each ftplugin because require() caches the module, and the mapping is buffer-local.
return function()
	vim.keymap.set("x", "<leader>!", ":!oxfmt --stdin-filepath=% ", {
		buffer = true,
		desc = "Filter selection through oxfmt",
	})
end
