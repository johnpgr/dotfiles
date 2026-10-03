vim.pack.add({
	"https://github.com/L3MON4D3/LuaSnip",
	"https://github.com/rafamadriz/friendly-snippets",
	{
		src = "https://github.com/saghen/blink.cmp",
		version = "v1.10.2",
	},
})

require("blink.cmp").setup({
	keymap = {
		preset = "none",
		["<C-space>"] = { "show", "hide" },
		["<CR>"] = { "accept", "fallback" },
		["<Tab>"] = { "accept", "snippet_forward", "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },
		["<C-y>"] = { "accept", "fallback" },
		["<C-n>"] = { "select_next", "fallback" },
		["<C-p>"] = { "select_prev", "fallback" },
	},
	snippets = { preset = "luasnip" },
	sources = {
		default = { "lsp", "buffer", "snippets", "path" },
	},
	completion = {
		list = {
			selection = { preselect = true, auto_insert = false },
			cycle = { from_top = false },
		},
		menu = {
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
})

require("luasnip.loaders.from_vscode").lazy_load()
require("luasnip").setup({})
