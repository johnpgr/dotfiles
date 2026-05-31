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
				".git",
			}

			vim.lsp.config("kotlin_lsp", {
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
				global_node_modules = vim.fn.has("win32") == 1
					and (vim.fn.expand("$APPDATA") .. "/npm/node_modules")
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

			vim.lsp.enable({
				"lua_ls",
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

	{ "mfussenegger/nvim-jdtls", ft = "java" },
	-- { "yioneko/nvim-vtsls", lazy = true },
}
