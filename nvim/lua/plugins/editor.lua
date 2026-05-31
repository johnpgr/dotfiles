-- Editor tools: compile-mode, conform, copilot, undotree, visual-multi,
-- text-case, abolish, dispatch, mini.bufremove, mini.align, mypy, dadbod, quicker

return {
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

	-- Mypy (Python type checking)
	{
		"feakuru/mypy.nvim",
		ft = "python",
		config = function()
			local mypy_mod = require("mypy")
			mypy_mod.setup()

			local mypy_cache = {}

			local function get_mypy_context(buf_path)
				local root = vim.fs.root(
					buf_path,
					{ ".venv", "pyproject.toml", "mypy.ini", ".mypy.ini", "setup.cfg", "setup.py" }
				) or vim.fs.root(buf_path, { ".git" }) or vim.fn.getcwd()

				if mypy_cache[root] then
					return mypy_cache[root]
				end

				local venv_mypy = vim.fs.joinpath(root, ".venv", "bin", "mypy")
				local cmd = vim.fn.executable(venv_mypy) == 1 and venv_mypy or "mypy"

				mypy_cache[root] = {
					cmd = cmd,
					cwd = root,
				}

				return mypy_cache[root]
			end

			mypy_mod.typecheck_current_buffer = function()
				if not mypy_mod.enabled then
					vim.diagnostic.reset(mypy_mod.namespace, 0)
					return
				end
				local buf_num = vim.api.nvim_get_current_buf()
				local buf_path = vim.api.nvim_buf_get_name(0)
				if buf_path == "" then
					return
				end

				local mypy_context = get_mypy_context(buf_path)
				local cmd = { mypy_context.cmd, "--show-error-end", "--follow-imports=silent" }
				for w in string.gmatch(mypy_mod.extra_args, "%S+") do
					table.insert(cmd, w)
				end
				table.insert(cmd, buf_path)

				pcall(vim.system, cmd, { cwd = mypy_context.cwd }, function(out)
					if out.code ~= 0 then
						local diagnostics = {}
						for line_from, col_from, line_to, col_to, severity, message in
							string.gmatch(out.stdout, "(%d+):(%d+):(%d+):(%d+): (%a+): ([^\n]+)")
						do
							table.insert(diagnostics, {
								lnum = tonumber(line_from) - 1,
								col = tonumber(col_from) - 1,
								end_lnum = tonumber(line_to) - 1,
								end_col = tonumber(col_to) - 1,
								message = "mypy: " .. message,
								severity = mypy_mod.severities[severity],
							})
						end
						vim.schedule(function()
							vim.diagnostic.set(mypy_mod.namespace, buf_num, diagnostics)
						end)
					else
						vim.schedule(function()
							vim.diagnostic.reset(mypy_mod.namespace, buf_num)
						end)
					end
				end)
			end

			vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
				group = vim.api.nvim_create_augroup("MypyNvim", { clear = true }),
				pattern = { "*.py", "*.pyi" },
				callback = function()
					mypy_mod.typecheck_current_buffer()
				end,
			})

			vim.api.nvim_create_user_command("MypyDebug", function()
				local buf_path = vim.api.nvim_buf_get_name(0)
				if buf_path == "" then
					print("mypy.nvim: current buffer has no file path")
					return
				end

				local mypy_context = get_mypy_context(buf_path)
				print(vim.inspect({
					buf_path = buf_path,
					cwd = mypy_context.cwd,
					cmd = mypy_context.cmd,
					cmd_executable = vim.fn.executable(mypy_context.cmd) == 1,
					extra_args = mypy_mod.extra_args,
				}))
			end, { desc = "Show resolved mypy command info" })
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

	-- Copilot
	{
		"zbirenbaum/copilot.lua",
		-- enabled = false,
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = {
					enabled = true,
					auto_trigger = true,
					hide_during_completion = true,
					debounce = 75,
					trigger_on_accept = true,
					keymap = {
						accept = "<M-l>",
						accept_word = false,
						accept_line = false,
						next = "<M-]>",
						prev = "<M-[>",
						dismiss = "<C-]>",
					},
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
