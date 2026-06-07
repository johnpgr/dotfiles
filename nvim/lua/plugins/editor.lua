-- Editor tools: conform, undotree, visual-multi,
-- text-case, abolish, dispatch, mini.bufremove, mini.align, mypy, dadbod, quicker

return {
    -- Lastplace (open files at last edit position)
	{ "farmergreg/vim-lastplace", lazy = false },

	-- Undotree
	{
		"mbbill/undotree",
		cmd = "UndotreeToggle",
		keys = {
			{ "<leader>tu", "<cmd>UndotreeToggle<cr>", desc = "Undotree" },
		},
	},

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
		end,
	},

	-- Abolish
	{ "tpope/vim-abolish", event = "VeryLazy" },

	-- Dispatch
	{ "tpope/vim-dispatch", cmd = { "Dispatch", "Make", "Focus", "Start" } },

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

	-- Dadbod (Database)
	{
		"tpope/vim-dadbod",
		cmd = { "DB", "DBUI", "DBUIAddConnection" },
		dependencies = {
			"kristijanhusak/vim-dadbod-completion",
			"kristijanhusak/vim-dadbod-ui",
		},
	},
	{ "kristijanhusak/vim-dadbod-completion", lazy = true },
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUI", "DBUIAddConnection", "DBUIToggle" },
		keys = {
			{ "<leader>ub", desc = "DBUI" },
			{ "<leader>ua", "<cmd>DBUIAddConnection<cr>", desc = "Add new connection" },
		},
	},

	-- Quicker (quickfix improvements)
	{
		"stevearc/quicker.nvim",
		ft = "qf",
		keys = {
			{
				"<leader>q",
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
