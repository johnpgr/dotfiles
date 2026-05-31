-- Colorscheme plugins

return {
	{ "farmergreg/vim-lastplace", lazy = false },
	{
		"alligator/accent.vim",
		lazy = false,
		config = function()
			-- vim.g.accent_colour = 'yellow'
			-- vim.g.accent_colour = 'orange'
			-- vim.g.accent_colour = 'red'
			-- vim.g.accent_colour = 'green'
			vim.g.accent_colour = "blue"
			-- vim.g.accent_colour = 'magenta'
			-- vim.g.accent_colour = 'cyan'
		end,
	},
	{ "silentium-theme/silentium.nvim", lazy = false },
	{ "rktjmp/lush.nvim", lazy = false },
	{ "fenetikm/falcon", lazy = false },
	{ "embark-theme/vim", name = "embark-theme", lazy = false },
	{ "axvr/photon.vim", lazy = false },
	{
		"https://github.com/sainnhe/everforest",
		config = function()
			vim.g.everforest_background = "soft"
			vim.g.everforest_better_performance = 1
			vim.g.everforest_disable_italic_comment = 1
			vim.g.everforest_disable_italic = 1
		end,
		lazy = false,
	},
	{
		"sainnhe/gruvbox-material",
		config = function()
			vim.g.gruvbox_material_background = "hard"
			vim.g.gruvbox_material_better_performance = 1
			vim.g.gruvbox_material_disable_italic_comment = 1
			vim.g.gruvbox_material_disable_italic = 1
			vim.g.gruvbox_material_foreground = "material"
		end,
		lazy = false,
	},
	{
		"travisvroman/adwaita.nvim",
		lazy = false,
		config = function()
			vim.g.adwaita_darker = true
		end,
	},
	{
		"2nthony/vitesse.nvim",
		lazy = false,
		dependencies = {
			"tjdevries/colorbuddy.nvim",
		},
		config = function()
			require("vitesse").setup({
				comment_italics = false,
				transparent_background = false,
				transparent_float_background = true, -- aka pum(popup menu) background
				reverse_visual = true,
				dim_nc = true,
				cmp_cmdline_disable_search_highlight_group = false, -- disable search highlight group for cmp item
				-- if `transparent_float_background` false, make telescope border color same as float background
				telescope_border_follow_float_background = false,
				-- similar to above, but for lspsaga
				lspsaga_border_follow_float_background = false,
				-- diagnostic virtual text background, like error lens
				diagnostic_virtual_text_background = false,

				-- override the `lua/vitesse/palette.lua`, go to file see fields
				colors = {},
				themes = {},
			})
		end,
	},
	{ "Mofiqul/vscode.nvim", lazy = false },
	{ "sainnhe/sonokai", lazy = false },
	{ "Mofiqul/dracula.nvim", lazy = false },
}
