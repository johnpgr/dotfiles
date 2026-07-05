-- Editor tools: conform, visual-multi, text-case, abolish,
-- blink.cmp, mini.bufremove, mini.align, mypy, quicker

vim.keymap.set("n", "<leader>tu", function()
	vim.cmd.packadd("nvim.undotree")
	vim.cmd.Undotree()
end, { desc = "Undotree" })

return {
	-- Lastplace (open files at last edit position)
	{ "farmergreg/vim-lastplace", lazy = false },

	-- Visual Multi (multiple cursors)
	{
		"mg979/vim-visual-multi",
		event = "VeryLazy",
		init = function()
			vim.cmd([[
                let g:VM_maps = {}
                let g:VM_maps["Goto Prev"] = "\[\["
                let g:VM_maps["Goto Next"] = "\]\]"
                nmap <C-M-n> <Plug>(VM-Select-All)
            ]])
		end,
	},

	-- Text Case
	{
		"johmsalas/text-case.nvim",
		event = "VeryLazy",
		config = function()
			require("textcase").setup({ prefix = "tc" })

			local conversions = {
				{ label = "camelCase",       key = "c", method = "to_camel_case" },
				{ label = "PascalCase",      key = "p", method = "to_pascal_case" },
				{ label = "snake_case",      key = "s", method = "to_snake_case" },
				{ label = "dash-case",       key = "d", method = "to_dash_case" },
				{ label = "CONSTANT_CASE",   key = "n", method = "to_constant_case" },
				{ label = "UPPER CASE",      key = "u", method = "to_upper_case" },
				{ label = "lower case",      key = "l", method = "to_lower_case" },
				{ label = "Title Case",      key = "t", method = "to_title_case" },
				{ label = "dot.case",        key = ".", method = "to_dot_case" },
				{ label = "Title-Dash Case", key = "T", method = "to_title_dash_case" },
				{ label = "Phrase case",     key = "P", method = "to_phrase_case" },
			}

			local function pick_case()
				vim.ui.select(conversions, {
					prompt = "Text case",
					format_item = function(item)
						return string.format("(%s) %s", item.key, item.label)
					end,
				}, function(choice)
					if choice then
						require("textcase").quick_replace(choice.method)
					end
				end)
			end

			vim.keymap.set({ "n", "x" }, "<leader>tc", pick_case, { desc = "Text case conversion" })
		end,
	},

	-- Abolish
	{ "tpope/vim-abolish", event = "VeryLazy" },

	-- Blink.cmp
	{
		"saghen/blink.cmp",
		version = "v1.10.2",
		event = "InsertEnter",
		dependencies = {
			"L3MON4D3/LuaSnip",
			"rafamadriz/friendly-snippets",
			"xzbdmw/colorful-menu.nvim",
		},
		config = function()
			require("config.completion").setup()
		end,
	},

	-- Mini Bufremove
	{
		"nvim-mini/mini.bufremove",
		keys = {
			{
				"<leader>x",
				function()
					require("mini.bufremove").delete()
				end,
				desc = "Delete buffer",
			},
		},
		config = function()
			require("mini.bufremove").setup()
		end,
	},

	-- Mini Align
	{
		"nvim-mini/mini.align",
		keys = {
			{ "ga", mode = { "n", "v" }, desc = "Align" },
			{ "gA", mode = { "n", "v" }, desc = "Align with preview" },
		},
		config = function()
			require("mini.align").setup({
				mappings = {
					start = "ga",
					start_with_preview = "gA",
				},
			})
		end,
	},
	-- Conform (formatting)
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		keys = {
			{
				"<leader>lf",
				function()
					require("conform").format({ async = true })
				end,
				desc = "Format buffer",
			},
		},
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua", lsp_format = "fallback" },
					python = { "isort", "black", lsp_format = "fallback" },
					rust = { "rustfmt", lsp_format = "fallback" },
					html = { "oxfmt", lsp_format = "fallback" },
					css = { "oxfmt", lsp_format = "fallback" },
					json = { "oxfmt", lsp_format = "fallback" },
					javascript = { "oxfmt", lsp_format = "fallback" },
					javascriptreact = { "oxfmt", lsp_format = "fallback" },
					typescript = { "oxfmt", lsp_format = "fallback" },
					typescriptreact = { "oxfmt", lsp_format = "fallback" },
					astro = { "oxfmt", lsp_format = "fallback" },
					c = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
					cpp = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
					odin = { lsp_format = "fallback" },
					zig = { lsp_format = "fallback" },
				},
			})
		end,
	},

	-- Quicker (quickfix improvements)
	{
		"stevearc/quicker.nvim",
		ft = "qf",
		keys = {
			{
				"<leader>c",
				function()
					require("quicker").toggle()
				end,
				desc = "Quickfix list",
			},
		},
		config = function()
			require("quicker").setup({
				keys = {
					{
						">",
						function()
							require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
						end,
						desc = "Expand quickfix context",
					},
					{
						"<",
						function()
							require("quicker").collapse()
						end,
						desc = "Collapse quickfix context",
					},
				},
			})
		end,
	},
}
