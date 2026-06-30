-- Treesitter and folding

return {
	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local nvim_treesitter = require("nvim-treesitter")
			local treesitter_dir = vim.fs.normalize(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter")
			local treesitter_languages = {
				"asm",
				"astro",
				"bash",
				"c",
				"cpp",
				"css",
				"dart",
				"git_config",
				"git_rebase",
				"gitcommit",
				"glsl",
				"html",
				"java",
				"javascript",
				"json",
				"kotlin",
				"lua",
				"markdown",
				"markdown_inline",
				"odin",
				"python",
				"query",
				"rust",
				"sql",
				"tsx",
				"typescript",
				"vim",
				"vimdoc",
				"zig",
			}

			if vim.fn.isdirectory(treesitter_dir) == 1 then
				vim.opt.rtp:remove(treesitter_dir)
				vim.opt.rtp:append(treesitter_dir)
			end

			nvim_treesitter.setup()
			local installed_languages = {}
			for _, ext in ipairs({ "*.so", "*.dll" }) do
				for _, file in ipairs(vim.api.nvim_get_runtime_file("parser/" .. ext, true)) do
					installed_languages[vim.fn.fnamemodify(file, ":t:r")] = true
				end
			end

			local missing_languages = vim.tbl_filter(function(lang)
				return not installed_languages[lang]
			end, treesitter_languages)

			if #missing_languages > 0 then
				nvim_treesitter.install(missing_languages)
			end

			local function is_large_buffer(bufnr)
				local bufname = vim.api.nvim_buf_get_name(bufnr)
				if bufname == "" then
					return false
				end

				local max_filesize = 1024 * 1024
				local ok, stats = pcall(vim.uv.fs_stat, bufname)
				return ok and stats and stats.size > max_filesize
			end

			local function resolve_lang(bufnr, lang)
				if lang and lang ~= "" then
					return lang
				end

				local filetype = vim.bo[bufnr].filetype
				local ok, resolved = pcall(vim.treesitter.language.get_lang, filetype)
				if ok and resolved then
					return resolved
				end

				local filetype_to_lang = {
					javascriptreact = "tsx",
					typescriptreact = "tsx",
				}

				return filetype_to_lang[filetype]
			end

			local ts_start = vim.treesitter.start

			local function start_treesitter(bufnr, lang)
				bufnr = bufnr or vim.api.nvim_get_current_buf()
				if vim.bo[bufnr].buftype ~= "" or is_large_buffer(bufnr) then
					return
				end

				local resolved_lang = resolve_lang(bufnr, lang)
				if resolved_lang then
					pcall(ts_start, bufnr, lang or resolved_lang)
				end
			end

			if vim.g.treesitter_enabled then
				local group = vim.api.nvim_create_augroup("TreesitterAutoStart", { clear = true })

				vim.api.nvim_create_autocmd("FileType", {
					group = group,
					callback = function(args)
						start_treesitter(args.buf)
					end,
				})

				vim.schedule(function()
					start_treesitter(vim.api.nvim_get_current_buf())
				end)
			else
				local allowed_langs = {
					markdown = true
				}

				---@diagnostic disable-next-line: duplicate-set-field
				vim.treesitter.start = function(bufnr, lang)
					bufnr = bufnr or vim.api.nvim_get_current_buf()
					local bufname = vim.api.nvim_buf_get_name(bufnr)
					if bufname == "" then
						return ts_start(bufnr, lang)
					end
					local resolved_lang = resolve_lang(bufnr, lang)
					if resolved_lang and allowed_langs[resolved_lang] then
						return ts_start(bufnr, lang or resolved_lang)
					end
				end
			end
		end,
	},

	-- Folding (disabled)
	{
		"kevinhwang91/nvim-ufo",
		enabled = false,
		dependencies = {
			"kevinhwang91/promise-async",
		},
		lazy = false,
		config = function()
			require("ufo").setup({
				provider_selector = function()
					return ""
				end,
			})
		end,
	},
	{ "kevinhwang91/promise-async", lazy = true },

	-- Status column (disabled)
	{
		"luukvbaal/statuscol.nvim",
		enabled = false,
		lazy = false,
		config = function()
			local builtin = require("statuscol.builtin")
			local function is_cursor_line(args)
				return args.actual_curwin == args.win and args.relnum == 0
			end

			require("statuscol").setup({
				segments = {
					{
						text = { builtin.foldfunc },
						condition = { is_cursor_line },
						click = "v:lua.ScFa",
					},
					{
						text = {
							function(args)
								return (" "):rep(args.fold.width)
							end,
						},
						condition = {
							function(args)
								return args.fold.width > 0 and not is_cursor_line(args)
							end,
						},
					},
					{ text = { "%s" }, click = "v:lua.ScSa" },
					{
						text = { builtin.lnumfunc, " " },
						condition = { true, builtin.not_empty },
						click = "v:lua.ScLa",
					},
				},
			})
		end,
	},
}
