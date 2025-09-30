local is_neovide = require("utils").is_neovide

-- General plugins
return {
	-- Dependency plugins (loaded by other plugins)
	{
		"kkharji/sqlite.lua",
		lazy = false,
	},
	{
		"nvim-lua/plenary.nvim",
		lazy = true,
	},
	{
		"nvim-tree/nvim-web-devicons",
		lazy = true,
		cond = vim.g.icons_enabled,
	},
	-- Colorschemes
	{
		"morhetz/gruvbox",
		lazy = false,
		priority = 1000,
	},
	{
		"rose-pine/neovim",
		name = "rosepine",
		lazy = false,
		priority = 1000,
		config = function()
			require("rose-pine").setup({
				styles = {
					bold = false,
					italic = false,
					transparency = true,
				},
			})
		end,
	},
	-- Session management
	{ "farmergreg/vim-lastplace", event = "BufReadPre" },
	-- UI enhancements
	{ "mbbill/undotree", cmd = "UndotreeToggle" },
	{ "hedyhli/outline.nvim", cmd = "Outline" },
	{
		"mg979/vim-visual-multi",
		lazy = true,
		keys = {
			{ "<C-n>", modes = "i" },
			{ "<C-M-n>", modes = "n" },
		},
		config = function()
			vim.cmd([[
                let g:VM_maps = {}
                let g:VM_maps["Goto Prev"] = "\[\["
                let g:VM_maps["Goto Next"] = "\]\]"
                nmap <C-M-n> <Plug>(VM-Select-All)
            ]])
		end,
	},
	-- Text manipulation
	{
		"johmsalas/text-case.nvim",
		keys = { "tc" },
		config = function()
			require("textcase").setup({
				prefix = "tc",
				substitude_command_name = "S",
			})
		end,
	},
	-- Indent guides
	{
		"lukas-reineke/indent-blankline.nvim",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("ibl").setup({
				indent = { char = "│" },
				enabled = false,
				scope = { enabled = false },
			})
		end,
	},
}
