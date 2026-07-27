local term = os.getenv("TERM")
local is_kitty = term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"

local lazy_pack = require("lazy_pack")

local load = lazy_pack.loader({ "https://github.com/NeogitOrg/neogit" }, function()
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
			mini_pick = false,
			telescope = false,
			fzf_lua = false,
			snacks = false,
		},
	})
end)

load = lazy_pack.on_command(load, { "Neogit", "NeogitLogCurrent" })

lazy_pack.on_keys(load, {
	{
		mode = "n",
		lhs = "<M-g>",
		desc = "Git status",
		fn = function()
			require("neogit").open({ kind = "split" })
		end,
	},
	{
		mode = "n",
		lhs = "<leader>gg",
		desc = "Git status",
		fn = function()
			require("neogit").open({ kind = "split" })
		end,
	},
	{
		mode = "n",
		lhs = "<leader>gc",
		desc = "Git commit",
		fn = function()
			require("neogit.buffers.commit_view").new("HEAD"):open("replace")
		end,
	},
	{
		mode = "n",
		lhs = "<leader>gb",
		desc = "Git branch",
		fn = function()
			vim.cmd("Neogit branch")
		end,
	},
	{
		mode = "n",
		lhs = "<leader>gL",
		desc = "Git log",
		fn = function()
			vim.cmd("NeogitLogCurrent")
		end,
	},
})
