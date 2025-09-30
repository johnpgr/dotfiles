local utils = require("utils")
local is_kitty = utils.is_kitty

-- Image preview
return {
	"3rd/image.nvim",
	ft = "markdown",
	cond = is_kitty,
	config = function()
		require("image").setup({
			integrations = {
				markdown = {
					only_render_image_at_cursor = true,
				},
			},
			hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
		})
	end,
}
