-- Misc: shared dependencies, pickers (fff),
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
}
