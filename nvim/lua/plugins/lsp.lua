-- LSP: nvim-lspconfig, mason, lazydev, jdtls

return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason-org/mason.nvim",
			"folke/lazydev.nvim",
			-- "yioneko/nvim-vtsls",
		},
		config = function()
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}

			vim.lsp.config("*", {
				capabilities = capabilities,
			})

			local kotlin_root_markers = {
				"settings.gradle.kts",
				"settings.gradle",
				"build.gradle.kts",
				"build.gradle",
				"pom.xml",
				"workspace.json",
			}

			local kotlin_lsp_cmd = vim.fn.stdpath("data") .. "/mason/bin/intellij-server"
			if vim.fn.executable(kotlin_lsp_cmd) ~= 1 then
				kotlin_lsp_cmd = "intellij-server"
			end

			vim.lsp.config("kotlin_lsp", {
				cmd = { kotlin_lsp_cmd, "--stdio" },
				root_dir = function(bufnr, on_dir)
					local fname = vim.api.nvim_buf_get_name(bufnr)
					if fname == "" then
						on_dir(vim.uv.cwd())
						return
					end
					local real_fname = vim.uv.fs_realpath(fname)
					local root = vim.fs.root(real_fname or fname, kotlin_root_markers)
					if not root and real_fname then
						root = vim.fs.root(fname, kotlin_root_markers)
					end
					on_dir(root or vim.fs.dirname(real_fname or fname) or vim.uv.cwd())
				end,
			})

			vim.lsp.config("asm_lsp", {
				filetypes = { "asm", "vmasm" },
				root_dir = function(bufnr, on_dir)
					local fname = vim.api.nvim_buf_get_name(bufnr)
					if fname == "" then
						on_dir(vim.uv.cwd())
						return
					end
					local root = vim.fs.root(fname, { ".asm-lsp.toml", ".git" })
					on_dir(root or vim.fs.dirname(fname) or vim.uv.cwd())
				end,
				get_language_id = function(_, filetype)
					if filetype == "dap-disassembly" then
						return "asm"
					end
					return filetype
				end,
				single_file_support = true,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "dap-disassembly",
				callback = function(args)
					if vim.fn.executable("asm-lsp") ~= 1 then
						return
					end
					vim.lsp.start({
						name = "asm_lsp",
						cmd = { "asm-lsp" },
						root_dir = vim.uv.cwd(),
						single_file_support = true,
						workspace_required = false,
						get_language_id = function()
							return "asm"
						end,
					}, {
						bufnr = args.buf,
						silent = true,
						reuse_client = function(client, config)
							return client.name == config.name and client.config.root_dir == config.root_dir
						end,
					})
				end,
			})

			local global_node_modules = ""
			if vim.fn.executable("npm") == 1 then
				global_node_modules = vim.fn.system("npm root -g"):gsub("[\r\n]", "")
			else
				global_node_modules = vim.fn.has("win32") == 1 and (vim.fn.expand("$APPDATA") .. "/npm/node_modules")
					or "/usr/local/lib/node_modules"
			end

			vim.lsp.config("ts_ls", {
				init_options = {
					plugins = {
						{
							name = "typescript-lit-html-plugin",
							location = global_node_modules,
						},
					},
				},
			})

			vim.lsp.config("wc_language_server", {
				filetypes = {
					"html",
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
					"astro",
					"vue",
					"svelte",
					"markdown",
				},
			})

			vim.lsp.config("c3_lsp", {
				cmd = { "c3lsp", "--stdlib-path=/opt/c3/lib/std" },
			})

			vim.lsp.enable({
				"lua_ls",
				-- "jdtls",
				-- "vtsls",
				"clangd",
				"html",
				"cssls",
				-- "tailwindcss",
				"jsonls",
				"pyright",
				"zls",
				"dartls",
				"glsl_analyzer",
				"kotlin_lsp",
				"astro",
				"rust_analyzer",
				"sqlls",
				"oxlint",
				"ols",
				"asm_lsp",
				"ts_ls",
				"ruff",
				"wc_language_server",
				"c3_lsp",
			})
		end,
	},

	{
		"mason-org/mason.nvim",
		lazy = false,
		cmd = { "Mason", "MasonInstall", "MasonUpdate" },
		build = ":MasonUpdate",
		config = function()
			require("mason").setup({})
		end,
	},

	{
		"folke/lazydev.nvim",
		ft = "lua",
		config = function()
			require("lazydev").setup({
				library = {
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			})
		end,
	},

	-- { "yioneko/nvim-vtsls", lazy = true },

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
	{ "code5717/c3.vim", ft = "c3" },
}
