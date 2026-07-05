-- UI plugins: neo-tree, oil, smart-splits, toggleterm,
-- which-key, transparent, indent-blankline, diagflow, image.nvim, cord

local term = os.getenv("TERM")
local is_kitty = term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"
local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0
local is_windows = vim.fn.has("win32") == 1

return {
	-- Colorschemes
	{
		"scottmckendry/cyberdream.nvim",
		event = "VeryLazy",
		config = function()
			require("cyberdream").setup({
				variant = vim.o.background == "light" and "light" or "default",
			})
		end,
	},
	{ "xiantang/darcula-dark.nvim", lazy = false },
	{ "travisvroman/adwaita.nvim", lazy = false },
	{
		"blazkowolf/gruber-darker.nvim",
		lazy = false,
		opts = {
			bold = false,
			italic = {
				strings = false,
			},
		},
	},
	-- Smart Splits (seamless navigation/resize across nvim + wezterm/kitty/tmux)
	{
		"johnpgr/smart-splits.nvim",
		branch = "perf/async-wezterm-cli",
		lazy = false,
		build = is_windows and nil or "./kitty/install-kittens.bash",
		config = function()
			require("smart-splits").setup({
				at_edge = "stop",
			})
		end,
	},

	-- Oil (file explorer / editor)
	{
		"stevearc/oil.nvim",
		lazy = false,
		dependencies = { "nvim-mini/mini.icons" },
		config = function()
			local permission_hlgroups = {
				["-"] = "NonText",
				["r"] = "DiagnosticSignWarn",
				["w"] = "DiagnosticSignError",
				["x"] = "DiagnosticSignOk",
			}
			local columns = {
				-- {
				-- 	"permissions",
				-- 	highlight = function(permission_str)
				-- 		local hls = {}
				-- 		for i = 1, #permission_str do
				-- 			local char = permission_str:sub(i, i)
				-- 			table.insert(hls, { permission_hlgroups[char], i - 1, i })
				-- 		end
				-- 		return hls
				-- 	end,
				-- },
				-- { "size", highlight = "Special" },
				-- { "mtime", highlight = "Number" },
			}

			if vim.g.icons_enabled then
				table.insert(columns, { "icon", add_padding = false })
			end

			local function oil_action_open_file()
				local oil = require("oil")
				local entry = oil.get_cursor_entry()
				local cwd = oil.get_current_dir()

				if not entry then
					return
				end

				local cmd = (vim.fn.has("mac") == 1) and "open" or (vim.fn.has("win32") == 1) and "start" or "xdg-open"

				local full_path = cwd .. entry.name
				vim.fn.jobstart({ cmd, full_path }, {
					on_exit = function(_, code)
						if code ~= 0 then
							vim.notify("Failed to open file: " .. entry.name, vim.log.levels.ERROR)
						end
					end,
				})
			end

			local function oil_action_run_cmd_on_file()
				local oil = require("oil")
				local entry = oil.get_cursor_entry()
				local cwd = oil.get_current_dir()

				if not entry then
					return
				end

				vim.ui.input({ prompt = "Enter command: " }, function(cmd)
					if not cmd then
						return
					end

					local full_path = cwd .. entry.name

					local function show_terminal(cmd_array)
						vim.cmd("botright new")
						vim.fn.jobstart(cmd_array, {
							on_exit = function(_, code)
								if code ~= 0 then
									vim.notify("Command exited with code: " .. code, vim.log.levels.WARN)
								end
							end,
							term = true,
						})
						vim.cmd("startinsert")
					end

					if cmd and cmd ~= "" then
						local command_string = cmd .. " " .. vim.fn.shellescape(full_path)
						show_terminal({ "sh", "-c", command_string })
					else
						local stat = vim.uv.fs_stat(full_path)
						if stat and stat.type == "file" then
							if bit.band(stat.mode, tonumber("100", 8)) > 0 then
								show_terminal({ full_path })
							else
								vim.ui.select({ "Yes", "No" }, {
									prompt = "File is not executable. Make it executable and run?",
								}, function(choice)
									if choice == "Yes" then
										local chmod_res = vim.system({ "chmod", "+x", full_path }):wait()
										if chmod_res.code == 0 then
											vim.notify("Made file executable: " .. entry.name)
											show_terminal({ full_path })
										else
											vim.notify(
												"Failed to make file executable: " .. entry.name,
												vim.log.levels.ERROR
											)
										end
									else
										vim.notify("Aborted execution of: " .. entry.name)
									end
								end)
							end
						else
							vim.notify("Not a valid file: " .. entry.name, vim.log.levels.WARN)
						end
					end
				end)
			end

			require("oil").setup({
				lsp_file_methods = { enabled = vim.version().minor ~= 12 },
				columns = columns,
				skip_confirm_for_simple_edits = true,
				view_options = {
					show_hidden = false,
					-- is_always_hidden = function(name, _)
					-- 	return name == ".." or name == "../"
					-- end,
				},
				keymaps = {
					["q"] = function()
						vim.api.nvim_win_close(0, true)
					end,
					["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
					["?"] = "actions.show_help",
					["<CR>"] = function()
						local oil = require("oil")
						local entry = oil.get_cursor_entry()
						if not entry then
							return
						end
						local dir = oil.get_current_dir()
						if not dir then
							return
						end
						local full_path = dir .. entry.name
						local stat = vim.uv.fs_stat(full_path)
						if stat and stat.type == "directory" then
							oil.select()
							return
						end

						local current_win = vim.api.nvim_get_current_win()
						local current_pos = vim.api.nvim_win_get_position(current_win)
						local current_row = current_pos[1]
						local current_col = current_pos[2]
						local current_width = vim.api.nvim_win_get_width(current_win)
						local above_win = nil
						local nearest_bottom = -1

						for _, win in ipairs(vim.api.nvim_list_wins()) do
							if win ~= current_win then
								local pos = vim.api.nvim_win_get_position(win)
								local row = pos[1]
								local col = pos[2]
								local height = vim.api.nvim_win_get_height(win)
								local width = vim.api.nvim_win_get_width(win)
								local bottom = row + height
								local overlaps_column = col < current_col + current_width and col + width > current_col
								if overlaps_column and bottom <= current_row and bottom > nearest_bottom then
									above_win = win
									nearest_bottom = bottom
								end
							end
						end

						if not above_win then
							oil.select()
							return
						end

						local above_buf = vim.api.nvim_win_get_buf(above_win)
						local above_is_empty = vim.api.nvim_buf_get_name(above_buf) == ""
							and vim.api.nvim_get_option_value("buftype", { buf = above_buf }) == ""
							and not vim.api.nvim_get_option_value("modified", { buf = above_buf })
							and vim.api.nvim_buf_line_count(above_buf) == 1
							and vim.api.nvim_buf_get_lines(above_buf, 0, 1, false)[1] == ""

						if not above_is_empty then
							oil.select()
						else
							vim.api.nvim_win_close(current_win, true)
							vim.api.nvim_set_current_win(above_win)
							vim.cmd("edit " .. vim.fn.fnameescape(full_path))
						end
					end,
					["<C-v>"] = { "actions.select", opts = { vertical = true } },
					["<C-x>"] = { "actions.select", opts = { horizontal = true } },
					["<F1>"] = oil_action_run_cmd_on_file,
					["<F5>"] = "actions.refresh",
					["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
					["<BS>"] = { "actions.parent", mode = "n" },
					["-"] = { "actions.parent", mode = "n" },
					["H"] = "actions.toggle_hidden",
					["<leader>o"] = oil_action_open_file,
				},
				confirmation = { border = "single" },
				win_options = {
					winbar = "%!v:lua.get_oil_winbar()",
					signcolumn = "no",
					foldcolumn = "0",
					number = false,
				},
				use_default_keymaps = false,
				watch_for_changes = true,
				constrain_cursor = "name",
			})
		end,
	},

	-- Which Key
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			local wk = require("which-key")
			wk.setup({
				preset = "helix",
				icons = { mappings = false },
				win = {
					border = "single",
					height = { min = 4, max = math.huge },
				},
			})
			wk.add({
				{ "<leader>f", group = "file" },
				{ "<leader>s", group = "search" },
				{ "<leader>g", group = "git" },
				{ "<leader>gl", group = "list" },
				{ "<leader>h", group = "hunk" },
				{ "<leader>l", group = "lsp" },
				{ "<leader>t", group = "toggle" },
				{ "<leader>i", group = "insert" },
			})
		end,
	},

	-- Transparent
	{
		"xiyaowong/transparent.nvim",
		lazy = false,
		config = function()
			require("transparent").setup({
				exclude_groups = {
					"CursorLine",
					"CursorLineNr",
					"StatusLine",
					"StatusLineNC",
				},
				extra_groups = {
					"VertSplit",
					"NormalFloat",
					"SignColumn",
					"FoldColumn",
					"WinBar",
					"WinBarNC",
					-- "TabLine",
					-- "TabLineSel",
					-- "TabLineFill",
					"Directory",
					"NeoTreeNormal",
					"NeoTreeNormalNC",
					"NeoTreeEndOfBuffer",
					"WhichKeyTitle",
					"FloatBorder",
					"SpecialKey",
				},
			})
		end,
	},

	-- Diagflow (virtual-text diagnostics)
	{ "dgagn/diagflow.nvim", opts = {}, event = "BufRead" },

	-- Indent Blankline
	{
		"lukas-reineke/indent-blankline.nvim",
		enabled = true,
		event = "BufRead",
		main = "ibl",
		keys = {
			{
				"<leader>ig",
				"<cmd>IBLToggle<cr>",
				desc = "Indent Guides",
			},
		},
		---@module "ibl"
		---@type ibl.config
		opts = {
			enabled = false,
			indent = { char = "│" },
			scope = { enabled = false },
		},
		config = function(_, opts)
			-- hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
			-- hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_tab_indent_level)
			require("ibl").setup(opts)
		end,
	},

	-- Image support (kitty / ghostty / wezterm only)
	{
		"3rd/image.nvim",
		enabled = image_enabled,
		ft = { "markdown", "image" },
		config = function()
			require("image").setup({
				backend = "kitty",
				processor = "magick_cli",
				integrations = {
					markdown = { only_render_image_at_cursor = true },
				},
				hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
			})
		end,
	},
}
