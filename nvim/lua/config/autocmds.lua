-- Autocmds and filetype registrations

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Detect image files and set filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
	callback = function()
		vim.bo.filetype = "image"
	end,
})

-- Start treesitter highlighting for any filetype with an installed parser,
-- respecting the global toggle (markdown is always kept on).
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("TreesitterToggle", { clear = true }),
	pattern = "*",
	callback = function(args)
		if vim.g.treesitter_enabled or args.match == "markdown" then
			pcall(vim.treesitter.start, args.buf)
		else
			vim.treesitter.stop(args.buf)
		end
	end,
})

-- Custom filetypes
vim.filetype.add({
	extension = {
		hlsl = "hlsl",
		m = "objc",
	},
})
