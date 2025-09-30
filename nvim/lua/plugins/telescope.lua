-- Telescope plugins
local utils = require("utils")
local default_picker_config = utils.default_picker_config

return {
	{
		"nvim-telescope/telescope.nvim",
		cmd = "Telescope",
		keys = {
			{
				"<leader>sc",
				function()
					require("telescope.builtin").colorscheme()
				end,
				desc = "Search colorscheme",
			},
			{
				"<leader>sh",
				function()
					require("telescope.builtin").help_tags()
				end,
				desc = "Search help",
			},
			{
				"<leader>sH",
				function()
					require("telescope.builtin").highlights()
				end,
				desc = "Search highlight group",
			},
			{
				"<leader>sd",
				function()
					require("telescope.builtin").live_grep({
						cwd = require("telescope.utils").buffer_dir(),
					})
				end,
				desc = "Search current directory",
			},
			{
				"<leader>sf",
				function()
					require("telescope.builtin").find_files({ cwd = require("telescope.utils").buffer_dir() })
				end,
				desc = "Search file",
			},
			{
				"<leader>/",
				function()
					require("telescope.builtin").live_grep()
				end,
				desc = "Search workspace",
			},
			{
				"<leader><space>",
				function()
					require("telescope.builtin").find_files()
				end,
				desc = "Find file in workspace",
			},
			{
				"<leader>so",
				function()
					require("telescope.builtin").vim_options()
				end,
				desc = "Search option",
			},
			{
				"<leader>fr",
				function()
					require("telescope.builtin").oldfiles({ prompt_title = "" })
				end,
				desc = "Recent files",
			},
			{
				"<leader>fn",
				function()
					require("telescope").extensions.file_browser.file_browser({ path = vim.fn.stdpath("config") })
				end,
				desc = "Browse .config/nvim",
			},
			{
				"<leader>ff",
				function()
					require("telescope").extensions.file_browser.file_browser()
				end,
				desc = "Find file",
			},
			{
				"<leader>.",
				function()
					require("telescope").extensions.file_browser.file_browser()
				end,
				desc = "Find file",
			},
			{
				"<leader>fw",
				function()
					require("telescope").extensions.file_browser.file_browser({ path = vim.fn.getcwd() })
				end,
				desc = "Find file in workspace",
			},
			{
				"<leader>fR",
				function()
					require("telescope.builtin").oldfiles({
						only_cwd = true,
						prompt_title = "",
					})
				end,
				desc = "Recent files in workspace",
			},
			{ "<leader>sb", utils.fuzzy_find_current_buffer, desc = "Search buffer" },
			{
				"<leader>sB",
				function()
					require("telescope.builtin").live_grep({ grep_open_files = true })
				end,
				desc = "Search buffer",
			},
			{
				"<leader>,",
				function()
					require("telescope.builtin").buffers({ prompt_title = "", only_cwd = true })
				end,
				desc = "Switch workspace buffers",
			},
			{
				"<leader><",
				function()
					require("telescope.builtin").buffers({ prompt_title = "" })
				end,
				desc = "Switch buffers",
			},
			{
				"<leader>'",
				function()
					require("telescope.builtin").resume()
				end,
				desc = "Resume last search",
			},
			{
				"<leader>is",
				function()
					require("telescope.builtin").symbols()
				end,
				desc = "Symbols",
			},
			{
				"<leader>ss",
				function()
					require("telescope.builtin").spell_suggest()
				end,
				desc = "Search spelling suggestion",
			},
			{
				"<leader>glg",
				function()
					require("telescope").extensions.gh.gist(
						require("telescope.themes").get_dropdown(default_picker_config)
					)
				end,
				desc = "List gists",
			},
			{
				"<leader>gli",
				function()
					require("telescope").extensions.gh.issues(
						require("telescope.themes").get_dropdown(default_picker_config)
					)
				end,
				desc = "List issues",
			},
			{
				"<leader>glp",
				function()
					require("telescope").extensions.gh.pull_request(
						require("telescope.themes").get_dropdown(default_picker_config)
					)
				end,
				desc = "List pull requests",
			},
		},
		dependencies = {
			"nvim-telescope/telescope-fzf-native.nvim",
			"nvim-telescope/telescope-ui-select.nvim",
			"johnpgr/telescope-file-browser.nvim",
			"nvim-telescope/telescope-symbols.nvim",
			"nvim-telescope/telescope-github.nvim",
		},
		config = function()
			require("telescope").setup({
				defaults = {
					mappings = {
						i = {
							["<C-q>"] = function(bufnr)
								require("telescope.actions").send_to_qflist(bufnr)
								vim.cmd("copen")
							end,
							["<Esc>"] = require("telescope.actions").close,
						},
					},
				},
				extensions = {
					file_browser = vim.tbl_extend("force", default_picker_config, {
						path = "%:p:h",
						prompt_path = true,
						git_status = false,
						hide_parent_dir = true,
						grouped = true,
						dir_icon = vim.g.icons_enabled and "" or " ",
						dir_icon_hl = "Directory",
						prompt_title = "",
						mappings = {
							i = {
								["<Tab>"] = function(bufnr)
									local fb_actions = require("telescope").extensions.file_browser.actions
									local entry = require("telescope.actions.state").get_selected_entry()
									local entry_path = entry.Path

									if entry_path:is_dir() then
										fb_actions.open_dir(bufnr, nil, entry.path)
									else
										local picker = require("telescope.actions.state").get_current_picker(bufnr)
										picker:set_prompt(entry.ordinal)
									end
								end,
								["<C-w>"] = require("telescope").extensions.file_browser.actions.backspace,
							},
						},
					}),
					fzf = {},
					["ui-select"] = {
						require("telescope.themes").get_dropdown(default_picker_config),
					},
				},
				pickers = {
					buffers = vim.tbl_extend("force", default_picker_config, {
						mappings = {
							i = {
								["<C-d>"] = require("telescope.actions").delete_buffer
									+ require("telescope.actions").move_to_top,
							},
						},
					}),
					find_files = default_picker_config,
					live_grep = default_picker_config,
					vim_options = default_picker_config,
					highlights = vim.tbl_extend("force", default_picker_config, {
						previewer = true,
					}),
					oldfiles = default_picker_config,
					help_tags = default_picker_config,
					commands = default_picker_config,
					colorscheme = vim.tbl_extend("force", default_picker_config, {
						enable_preview = true,
						mappings = {
							n = {
								["<CR>"] = function(bufnr)
									local actions = require("telescope.actions")
									local action_state = require("telescope.actions.state")
									local selection = action_state.get_selected_entry()
									local colors_selected = selection.value

									require("colorscheme").persist_colorscheme(colors_selected)
									actions.close(bufnr)
									vim.cmd("colorscheme " .. colors_selected)
								end,
							},
							i = {
								["<CR>"] = function(bufnr)
									local actions = require("telescope.actions")
									local action_state = require("telescope.actions.state")
									local selection = action_state.get_selected_entry()
									local colors_selected = selection.value

									require("colorscheme").persist_colorscheme(colors_selected)
									actions.close(bufnr)
									vim.cmd("colorscheme " .. colors_selected)
								end,
							},
						},
					}),
					spell_suggest = default_picker_config,
					reloader = default_picker_config,
					current_buffer_fuzzy_find = default_picker_config,
					symbols = default_picker_config,
				},
			})

			require("telescope").load_extension("ui-select")
			require("telescope").load_extension("fzf")
			require("telescope").load_extension("file_browser")
			require("telescope").load_extension("gh")
		end,
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
		lazy = true,
	},
	{
		"nvim-telescope/telescope-ui-select.nvim",
		lazy = true,
	},
	{
		"johnpgr/telescope-file-browser.nvim",
		branch = "absolute-path-prompt-prefix",
		lazy = true,
	},
	{
		"nvim-telescope/telescope-symbols.nvim",
		lazy = true,
	},
	{
		"nvim-telescope/telescope-github.nvim",
		lazy = true,
	},
}
