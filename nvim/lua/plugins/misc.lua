-- Misc: shared dependencies, pickers (fff + mini.pick),
-- scope, neovim-project, mise

return {
	-- Icons (LSP completion kinds + devicons API for oil.nvim)
	{
		"nvim-mini/mini.icons",
		lazy = false,
		config = function()
			require("mini.icons").setup({
				lsp = {
					["function"] = { glyph = "󰆧" },
				},
			})
			MiniIcons.mock_nvim_web_devicons()
		end,
	},

	-- FFF (Fast File Finder)
	{
		"dmtrKovalenko/fff.nvim",
		event = "VeryLazy",
		build = function()
			pcall(function()
				require("fff.download").download_or_build_binary()
			end)
		end,
	},

	-- Mini.pick (picker UI)
	{
		"nvim-mini/mini.pick",
		version = false,
		event = "VeryLazy",
		config = function()
			local pick = require("mini.pick")
			pick.setup({
				window = {
					config = {
						border = "single",
					},
				},
			})
			vim.ui.select = pick.ui_select
		end,
	},
}
