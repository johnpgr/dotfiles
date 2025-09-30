-- Tmux integration
return {
	"aserowy/tmux.nvim",
	lazy = true, -- load only when a keymap is pressed
	keys = {
		{
			"<C-k>",
			function()
				require("tmux").move_top()
			end,
			desc = "Move top",
		},
		{
			"<C-l>",
			function()
				require("tmux").move_right()
			end,
			desc = "Move right",
		},
		{
			"<C-j>",
			function()
				require("tmux").move_bottom()
			end,
			desc = "Move bottom",
		},
		{
			"<C-h>",
			function()
				require("tmux").move_left()
			end,
			desc = "Move left",
		},
		{
			"<A-k>",
			function()
				require("tmux").resize_top()
			end,
			desc = "Resize top",
		},
		{
			"<A-l>",
			function()
				require("tmux").resize_right()
			end,
			desc = "Resize right",
		},
		{
			"<A-j>",
			function()
				require("tmux").resize_bottom()
			end,
			desc = "Resize bottom",
		},
		{
			"<A-h>",
			function()
				require("tmux").resize_left()
			end,
			desc = "Resize left",
		},
	},
	config = function()
		require("tmux").setup({
			copy_sync = {
				enable = false,
			},
		})
	end,
}
