vim.pack.add({
	"https://github.com/folke/lazydev.nvim",
	"https://github.com/neovim/nvim-lspconfig",
})

require("lazydev").setup({
	library = {
		{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
	},
})

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

-- TypeScript: prefer native TS7 LSP (`tsc --lsp` / `tsgo`), fall back to `ts_ls`.
-- Only one of the two attaches per buffer (root_dir gating + LspAttach dedupe).
local ts_native_lsp_cache = {}

---@param bin string
---@return boolean
local function typescript_bin_supports_native_lsp(bin)
	local cached = ts_native_lsp_cache[bin]
	if cached ~= nil then
		return cached
	end

	local basename = vim.fs.basename(bin)
	if basename == "tsgo" or basename == "tsgo.exe" then
		ts_native_lsp_cache[bin] = true
		return true
	end

	local version = vim.fn.system({ bin, "--version" })
	if vim.v.shell_error == 0 then
		local major = tonumber(version:match("(%d+)"))
		if major and major >= 7 then
			ts_native_lsp_cache[bin] = true
			return true
		end
	end

	-- `tsc --lsp --help` prints usage on stderr and exits 2; treat that as support.
	local result = vim.system({ bin, "--lsp", "--help" }, { text = true }):wait()
	local help = (result.stdout or "") .. (result.stderr or "")
	local supported = help:find("Usage of lsp", 1, true) ~= nil
	ts_native_lsp_cache[bin] = supported
	return supported
end

---@param root_dir? string
---@return string?
local function resolve_native_typescript_bin(root_dir)
	local candidates = {}
	if root_dir and root_dir ~= "" then
		vim.list_extend(candidates, {
			vim.fs.joinpath(root_dir, "node_modules", ".bin", "tsc"),
			vim.fs.joinpath(root_dir, "node_modules", ".bin", "tsgo"),
		})
	end
	for _, name in ipairs({ "tsc", "tsgo" }) do
		if vim.fn.executable(name) == 1 then
			candidates[#candidates + 1] = vim.fn.exepath(name)
		end
	end

	local seen = {}
	for _, bin in ipairs(candidates) do
		if bin and bin ~= "" and not seen[bin] and vim.fn.executable(bin) == 1 then
			seen[bin] = true
			if typescript_bin_supports_native_lsp(bin) then
				return bin
			end
		end
	end
end

---@param bufnr integer
---@return string?
local function js_ts_project_root(bufnr)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	-- Skip oil://, fugitive://, etc. Falling back to cwd would still attach and
	-- send a non-file URI to the server (see nvim-lspconfig#4345).
	if fname:match("^%a+://") then
		return nil
	end
	if vim.bo[bufnr].buftype ~= "" then
		return nil
	end

	-- Match nvim-lspconfig tsgo/ts_ls monorepo + Deno exclusion rules.
	local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
	root_markers = vim.fn.has("nvim-0.11.3") == 1 and { root_markers, { ".git" } }
		or vim.list_extend(root_markers, { ".git" })

	local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
	local deno_lock_root = vim.fs.root(bufnr, { "deno.lock" })
	local project_root = vim.fs.root(bufnr, root_markers)

	if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
		return nil
	end
	if deno_root and (not project_root or #deno_root >= #project_root) then
		return nil
	end

	return project_root or vim.fn.getcwd()
end

-- nvim-lspconfig's pack copy may not ship lsp/tsgo.lua yet; without filetypes
-- Neovim treats the client as "all filetypes" and tsc --lsp panics on .lua/.md/etc.
local ts_filetypes = {
	"javascript",
	"javascriptreact",
	"javascript.jsx",
	"typescript",
	"typescriptreact",
	"typescript.tsx",
}

vim.lsp.config("tsgo", {
	cmd = function(dispatchers, config)
		local bin = resolve_native_typescript_bin((config or {}).root_dir) or "tsc"
		return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
	end,
	filetypes = ts_filetypes,
	root_dir = function(bufnr, on_dir)
		local root = js_ts_project_root(bufnr)
		if not root or not resolve_native_typescript_bin(root) then
			return
		end
		on_dir(root)
	end,
})

vim.lsp.config("ts_ls", {
	root_dir = function(bufnr, on_dir)
		local root = js_ts_project_root(bufnr)
		-- Native TS7 LSP wins when available; keep ts_ls as fallback only.
		if not root or resolve_native_typescript_bin(root) then
			return
		end
		on_dir(root)
	end,
})

-- `npm root -g` is a slow sync spawn (~200-350ms); only pay that cost once,
-- when a JS/TS buffer is actually opened, instead of on every startup.
-- Only relevant for the ts_ls fallback (tsserver plugins).
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	once = true,
	callback = function()
		local global_node_modules
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
	end,
})

-- Safety nets: detach from non-file buffers; if both TS clients attach, keep native.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("typescript-lsp-dedupe", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client or (client.name ~= "tsgo" and client.name ~= "ts_ls") then
			return
		end

		local fname = vim.api.nvim_buf_get_name(args.buf)
		if fname:match("^%a+://") or vim.bo[args.buf].buftype ~= "" then
			vim.schedule(function()
				pcall(vim.lsp.buf_detach_client, args.buf, client.id)
			end)
			return
		end

		for _, other in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
			if other.id ~= client.id and (other.name == "tsgo" or other.name == "ts_ls") then
				local drop = client.name == "ts_ls" and client or other.name == "ts_ls" and other
				if drop then
					drop:stop(true)
				end
			end
		end
	end,
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

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME .. "/lua",
					"${3rd}/luv/library",
				},
			},
		},
	},
})

vim.lsp.config("c3_lsp", {
	cmd = { "c3lsp", "--stdlib-path=/opt/c3/lib/std" },
})

vim.lsp.enable({
	"lua_ls",
	"clangd",
	"html",
	"cssls",
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
	"tsgo",
	"ts_ls",
	"ruff",
	"wc_language_server",
	"c3_lsp",
})
