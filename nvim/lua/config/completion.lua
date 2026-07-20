-- Completion: blink.cmp, LuaSnip, snippets, colorful-menu

local M = {}

function M.setup()
	local function has_words_before()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		if col == 0 then
			return false
		end
		local line = vim.api.nvim_get_current_line()
		return line:sub(col, col):match("%s") == nil
	end

	local function toggle_menu(cmp)
		if not require("blink.cmp").is_visible() then
			cmp.show()
		else
			cmp.hide()
		end
	end

	local function custom_insert_next(cmp)
		if not cmp.is_active() then
			return cmp.show_and_insert()
		end
		vim.schedule(function()
			require("blink.cmp.completion.list").select_next({ auto_insert = true })
		end)
		return true
	end

	local function custom_insert_prev(cmp)
		if not cmp.is_active() then
			return cmp.show_and_insert()
		end
		vim.schedule(function()
			require("blink.cmp.completion.list").select_prev({ auto_insert = true })
		end)
		return true
	end

	local function emacs_tab(cmp)
		if require("blink.cmp").is_visible() then
			return cmp.select_and_accept()
		elseif has_words_before() then
			return custom_insert_next(cmp)
		end
	end

	local function tab_action(cmp)
		if vim.g.emacs_tab == true then
			return emacs_tab(cmp)
		end
		if require("blink.cmp").is_visible() then
			return cmp.accept()
		end
	end

	require("blink.cmp").setup({
		appearance = {
			kind_icons = vim.g.icons_enabled and {
				Text = "",
				Method = "",
				Function = "",
				Constructor = "",
				Field = "",
				Variable = "",
				Class = "",
				Interface = "",
				Module = "",
				Property = "",
				Unit = "",
				Value = "",
				Enum = "",
				Keyword = "",
				Snippet = "",
				Color = "",
				File = "",
				Reference = "",
				Folder = "",
				EnumMember = "",
				Constant = "",
				Struct = "",
				Event = "",
				Operator = "",
				TypeParameter = "",
			} or {
				Text = "",
				Method = "",
				Function = "",
				Constructor = "",
				Field = "",
				Variable = "",
				Class = "",
				Interface = "",
				Module = "",
				Property = "",
				Unit = "",
				Value = "",
				Enum = "",
				Keyword = "",
				Snippet = "",
				Color = "",
				File = "",
				Reference = "",
				Folder = "",
				EnumMember = "",
				Constant = "",
				Struct = "",
				Event = "",
				Operator = "",
				TypeParameter = "",
			},
		},
		keymap = {
			preset = "none",
			["<C-space>"] = { toggle_menu },
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = { tab_action, "snippet_forward", "fallback" },
			["<S-Tab>"] = { custom_insert_prev },
			["<C-y>"] = { "accept", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
		},
		snippets = { preset = "luasnip" },
		sources = {
			default = { "lsp", "buffer", "snippets", "path" },
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},
			},
			per_filetype = {
				lua = { "lazydev", "lsp", "buffer", "snippets", "path" },
				sql = { "snippets", "dadbod", "buffer" },
				DressingInput = { "buffer", "path" },
			},
		},
		completion = {
			list = {
				selection = { preselect = vim.g.emacs_tab ~= true },
				cycle = { from_top = false },
			},
			menu = {
				auto_show = vim.g.emacs_tab ~= true,
				max_height = 20,
				draw = {
					columns = vim.g.icons_enabled and { { "kind_icon" }, { "label", gap = 1 } }
						or { { "label", gap = 1 }, { "source_name" } },
					components = {
						source_name = {
							text = function(ctx)
								return "[" .. ctx.source_name .. "]"
							end,
						},
						label = {
							text = function(ctx)
								return require("colorful-menu").blink_components_text(ctx)
							end,
							highlight = function(ctx)
								return require("colorful-menu").blink_components_highlight(ctx)
							end,
						},
					},
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 250,
				window = { border = "single" },
			},
		},
		cmdline = { enabled = false },
		fuzzy = { implementation = "lua" },
	})

	require("luasnip.loaders.from_vscode").lazy_load()
	require("luasnip").setup({})
	require("colorful-menu").setup({})
end

return M
