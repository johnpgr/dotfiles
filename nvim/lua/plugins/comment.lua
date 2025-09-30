-- Comments
return {
	"echasnovski/mini.comment",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
	config = function()
		require("mini.comment").setup({
			options = {
				custom_commentstring = function()
					return require("ts_context_commentstring.internal").calculate_commentstring()
						or vim.bo.commentstring
				end,
			},
			mappings = {
				comment_line = "gcc",
				comment_visual = "gc",
			},
		})
	end,
}
