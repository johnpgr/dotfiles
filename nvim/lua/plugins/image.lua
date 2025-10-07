local utils = require("utils")
local is_kitty = utils.is_kitty

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
	callback = function()
		vim.bo.filetype = "image"
	end,
})

-- Image preview
return {
	"3rd/image.nvim",
	ft = { "markdown", "typst", "image" },
	cond = is_kitty,
	config = function()
		---@diagnostic disable-next-line: missing-fields
		require("image").setup({
			backend = "kitty", -- or "ueberzug" or "sixel"
			processor = "magick_cli", -- or "magick_rock"
			integrations = {
				markdown = {
					only_render_image_at_cursor = true,
				},
			},
			hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
		})
	end,
}
