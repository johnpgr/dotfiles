-- Editor tools: compile-mode, conform, undotree, visual-multi,
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

	-- Compile Mode
	{
		"ej-shafran/compile-mode.nvim",
		version = "^5.0.0",
		dependencies = { "m00qek/baleia.nvim" },
		cmd = { "Compile", "Recompile" },
		config = function()
			local compile_mode = require("compile-mode")
			local compile_mode_group = vim.api.nvim_create_augroup("CompileModeConfig", { clear = true })

			vim.api.nvim_create_autocmd("FileType", {
				group = compile_mode_group,
				pattern = "compilation",
				callback = function(args)
					vim.bo[args.buf].buflisted = false
				end,
			})

			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "compilation" then
					vim.bo[buf].buflisted = false
				end
			end

			vim.g.compile_mode = {
				default_command = "",
				input_word_completion = true,
				baleia_setup = true,
				bang_expansion = true,
				error_regexp_table = {
					nodejs = {
						regex = "^\\s\\+at .\\+ (\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\))$",
						filename = 1,
						row = 2,
						col = 3,
						priority = 2,
					},
					typescript = {
						regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
						filename = 1,
						row = 2,
						col = 3,
					},
					typescript_new = {
						regex = "^\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\) - error TS[1-9][0-9]*:",
						filename = 1,
						row = 2,
						col = 3,
					},
					gradlew = {
						regex = "^e:\\s\\+file://\\(.\\+\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
						filename = 1,
						row = 2,
						col = 3,
					},
					ls_lint = {
						regex = "\\v^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} (.+) failed for rules: .+$",
						filename = 1,
					},
					sass = {
						regex = "\\s\\+\\(.\\+\\) \\(\\d\\+\\):\\(\\d\\+\\)  .*$",
						filename = 1,
						row = 2,
						col = 3,
						type = compile_mode.level.WARNING,
					},
					kotlin = {
						regex = "^\\%(e\\|w\\): file://\\(.*\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
						filename = 1,
						row = 2,
						col = 3,
					},
					rust = {
						regex = "^\\s*-->\\s\\+\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)$",
						filename = 1,
						row = 2,
						col = 3,
						priority = 2,
					},
					odin = {
						regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)) Error:",
						filename = 1,
						row = 2,
						col = 3,
					},
				},
			}
		end,
	},

	-- Baleia (ANSI colors for compile-mode)
	{ "m00qek/baleia.nvim", version = "v1.3.0", lazy = true },

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
