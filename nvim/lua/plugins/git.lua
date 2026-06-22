-- Git: gitsigns, neogit, diffview

local term = os.getenv("TERM")
local is_kitty = term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"

return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				attach_to_untracked = true,
				preview_config = {
					border = "single",
					focusable = false,
				},
			})
		end,
	},

	{
		"NeogitOrg/neogit",
		dependencies = { "sindrets/diffview.nvim", "nvim-mini/mini.pick" },
		cmd = { "Neogit", "NeogitLogCurrent" },
		keys = {
			{
				"<M-g>",
				function()
					require("neogit").open({ kind = "split" })
				end,
				desc = "Git status",
			},
			{
				"<leader>gg",
				function()
					require("neogit").open({ kind = "split" })
				end,
				desc = "Git status",
			},
			{
				"<leader>gc",
				function()
					require("neogit.buffers.commit_view").new("HEAD"):open("replace")
				end,
				desc = "Git commit",
			},
			{ "<leader>gb", "<cmd>Neogit branch<cr>", desc = "Git branch" },
			{ "<leader>gL", "<cmd>NeogitLogCurrent<cr>", desc = "Git log" },
		},
		config = function()
			require("neogit").setup({
				graph_style = is_kitty and "kitty" or "ascii",
				commit_editor = {
					kind = "vsplit",
					show_staged_diff = false,
				},
				console_timeout = 5000,
				auto_show_console = false,
				integrations = {
					diffview = true,
					mini_pick = true,
					telescope = false,
					fzf_lua = false,
					snacks = false,
				},
			})
		end,
	},

	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewFileHistory" },
		keys = {
			{ "<leader>gD", ":DiffviewOpen ", desc = "Git DiffView" },
			{
				"<leader>gh",
				function()
					vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
				end,
				desc = "Git file history (Current)",
			},
			{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git file history (All)" },
		},
		config = function()
			require("diffview").setup({
				view = {
					merge_tool = {
						layout = "diff3_mixed",
						disable_diagnostics = true,
						winbar_info = true,
					},
				},
			})
		end,
	},
}
