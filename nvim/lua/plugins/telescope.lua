-- Telescope plugins
local utils = require("utils")

return {
	"nvim-telescope/telescope.nvim",
	cmd = "Telescope",
	keys = {
		-- {
		-- 	"<leader>sc",
		-- 	function()
		-- 		require("telescope.builtin").colorscheme()
		-- 	end,
		-- 	desc = "Search colorscheme",
		-- },
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
				require("utils").live_multi_grep({
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
			"<leader>sp",
			function()
				require("telescope.builtin").find_files({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy") })
			end,
			desc = "Search file in plugins",
		},
		{
			"<leader>/",
			function()
				require("utils").live_multi_grep()
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
				require("telescope.builtin").oldfiles()
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
			"<leader>fp",
			function()
				require("telescope").extensions.file_browser.file_browser({
					path = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
				})
			end,
			desc = "Find file in plugins",
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
				})
			end,
			desc = "Recent files in workspace",
		},
		{ "<leader>sb", utils.fuzzy_find_current_buffer, desc = "Search buffer" },
		{
			"<leader>ll",
			function()
				require("telescope.builtin").diagnostics({ path_display = { "filename_first" } })
			end,
			desc = "Diagnostic List",
		},
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
				require("telescope.builtin").buffers({ only_cwd = true })
			end,
			desc = "Switch workspace buffers",
		},
		{
			"<leader><",
			function()
				require("telescope.builtin").buffers({})
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
			"<leader>st",
			function()
				require("telescope.builtin").builtin()
			end,
			desc = "Telescope builtin pickers",
		},
		{
			"<leader>glg",
			function()
				require("telescope").extensions.gh.gist(
					require("telescope.themes").get_dropdown(require("telescope.config").values)
				)
			end,
			desc = "List gists",
		},
		{
			"<leader>gli",
			function()
				require("telescope").extensions.gh.issues(
					require("telescope.themes").get_dropdown(require("telescope.config").values)
				)
			end,
			desc = "List issues",
		},
		{
			"<leader>glp",
			function()
				require("telescope").extensions.gh.pull_request(
					require("telescope.themes").get_dropdown(require("telescope.config").values)
				)
			end,
			desc = "List pull requests",
		},
		{
			"grr",
			function()
				require("telescope.builtin").lsp_references()
			end,
			desc = "LSP References",
		},
		{
			"grt",
			function()
				require("telescope.builtin").lsp_type_definitions()
			end,
			desc = "LSP References",
		},
		{
			"grt",
			function()
				require("telescope.builtin").lsp_implementations()
			end,
			desc = "LSP References",
		},
	},
	dependencies = {
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
		},
		{
			"nvim-telescope/telescope-ui-select.nvim",
		},
		{
			"johnpgr/telescope-file-browser.nvim",
			branch = "absolute-path-prompt-prefix",
		},
		{
			"nvim-telescope/telescope-symbols.nvim",
		},
		{
			"nvim-telescope/telescope-github.nvim",
		},
	},
	config = function()
		require("telescope").setup({
			defaults = {
				theme = "dropdown",
				preview = false,
				borderchars = {
					{ "─", "│", "─", "│", "┌", "┐", "┘", "└" },
					prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
					results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
					preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
				},
				sorting_strategy = "ascending",
				layout_strategy = "center",
				layout_config = {
					preview_cutoff = 0, -- Preview should always show (unless previewer = false)
					width = 0.6,
					height = function(_, _, max_lines)
						return math.min(max_lines, 15)
					end,
				},
				results_title = "",
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
				file_browser = {
					path = "%:p:h",
					prompt_path = true,
					git_status = false,
					hide_parent_dir = true,
					grouped = true,
					dir_icon = vim.g.icons_enabled and "" or " ",
					dir_icon_hl = "Directory",
					prompt_title = "Find Files",
					results_title = "",
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
							["<C-w>"] = function(prompt_bufnr, bypass)
								local fb_actions = require("telescope").extensions.file_browser.actions
								local current_picker =
									require("telescope.actions.state").get_current_picker(prompt_bufnr)

								if current_picker:_get_prompt() == "" then
									fb_actions.goto_parent_dir(prompt_bufnr, bypass)
								else
									local prompt = current_picker:_get_prompt()
									local new_prompt = prompt:match("^(.-)%s*%S*$") or ""
									current_picker:set_prompt(new_prompt)
								end
							end,
						},
					},
				},
				fzf = {},
				["ui-select"] = {},
			},
			pickers = {
				buffers = {
					mappings = {
						i = {
							["<C-d>"] = require("telescope.actions").delete_buffer,
						},
					},
				},
				highlights = {
					preview = true,
				},
				-- colorscheme = {
				-- 	previewer = false,
				-- 	enable_preview = true,
				-- 	mappings = {
				-- 		n = {
				-- 			["<CR>"] = function(bufnr)
				-- 				local actions = require("telescope.actions")
				-- 				local action_state = require("telescope.actions.state")
				-- 				local selection = action_state.get_selected_entry()
				-- 				local colors_selected = selection.value
				--
				-- 				require("colorscheme").persist_colorscheme(colors_selected)
				-- 				actions.close(bufnr)
				-- 				vim.cmd("colorscheme " .. colors_selected)
				-- 			end,
				-- 		},
				-- 		i = {
				-- 			["<CR>"] = function(bufnr)
				-- 				local actions = require("telescope.actions")
				-- 				local action_state = require("telescope.actions.state")
				-- 				local selection = action_state.get_selected_entry()
				-- 				local colors_selected = selection.value
				--
				-- 				require("colorscheme").persist_colorscheme(colors_selected)
				-- 				actions.close(bufnr)
				-- 				vim.cmd("colorscheme " .. colors_selected)
				-- 			end,
				-- 		},
				-- 	},
				-- },
			},
		})

		require("telescope").load_extension("ui-select")
		require("telescope").load_extension("fzf")
		require("telescope").load_extension("file_browser")
		require("telescope").load_extension("gh")
	end,
}
