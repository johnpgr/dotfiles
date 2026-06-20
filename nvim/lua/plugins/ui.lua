-- UI plugins: neo-tree, oil, smart-splits, toggleterm,
-- which-key, transparent, indent-blankline, diagflow, image.nvim, cord

local term = os.getenv("TERM")
local is_kitty = term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"
local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0
local is_neovide = vim.g.neovide ~= nil
local is_windows = vim.fn.has("win32") == 1

return {
	-- Smart Splits (seamless navigation/resize across nvim + wezterm/kitty/tmux)
	{
		"johnpgr/smart-splits.nvim",
		branch = "perf/async-wezterm-cli",
		lazy = false,
		build = is_windows and nil or "./kitty/install-kittens.bash",
		keys = {
			{
				"<C-h>",
				function()
					require("smart-splits").move_cursor_left()
				end,
				desc = "Focus split left",
			},
			{
				"<C-j>",
				function()
					require("smart-splits").move_cursor_down()
				end,
				desc = "Focus split down",
			},
			{
				"<C-k>",
				function()
					require("smart-splits").move_cursor_up()
				end,
				desc = "Focus split up",
			},
			{
				"<C-l>",
				function()
					require("smart-splits").move_cursor_right()
				end,
				desc = "Focus split right",
			},
			{
				"<M-h>",
				function()
					require("smart-splits").resize_left()
				end,
				desc = "Resize split left",
			},
			{
				"<M-j>",
				function()
					require("smart-splits").resize_down()
				end,
				desc = "Resize split down",
			},
			{
				"<M-k>",
				function()
					require("smart-splits").resize_up()
				end,
				desc = "Resize split up",
			},
			{
				"<M-l>",
				function()
					require("smart-splits").resize_right()
				end,
				desc = "Resize split right",
			},
		},
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
		keys = {
			{ "<leader>e", "<cmd>Oil<cr>", desc = "Explore" },
		},
		config = function()
			local permission_hlgroups = {
				["-"] = "NonText",
				["r"] = "DiagnosticSignWarn",
				["w"] = "DiagnosticSignError",
				["x"] = "DiagnosticSignOk",
			}
			local columns = {
				{
				    "permissions",
				    highlight = function(permission_str)
				        local hls = {}
				        for i = 1, #permission_str do
				            local char = permission_str:sub(i, i)
				            table.insert(hls, { permission_hlgroups[char], i - 1, i })
				        end
				        return hls
				    end,
				},
				{ "size",  highlight = "Special" },
				{ "mtime", highlight = "Number" },
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

				local cmd = (vim.fn.has("mac") == 1) and "open"
					or (vim.fn.has("win32") == 1) and "start"
					or "xdg-open"

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
					["q"] = "actions.close",
					["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
					["?"] = "actions.show_help",
					["<CR>"] = "actions.select",
					["<F1>"] = oil_action_run_cmd_on_file,
					["<F5>"] = "actions.refresh",
					["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
					["-"] = { "actions.parent", mode = "n" },
					["<Left>"] = { "actions.parent", mode = "n" },
					["<Right>"] = { "actions.select", mode = "n" },
					["H"] = "actions.toggle_hidden",
					["<leader>o"] = oil_action_open_file,
				},
				confirmation = { border = "single" },
				win_options = {
					winbar = "%!v:lua.get_oil_winbar()",
					signcolumn = "no",
					foldcolumn = "0",
                    number = false
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
					height = { min = 4, max = 10 },
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
				{ "<leader>d", group = "debug" },
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

	-- Cord (Discord presence)
	{
		"vyfor/cord.nvim",
		event = "VeryLazy",
		config = function()
			require("cord").setup({})
		end,
	},

	-- Toggleterm
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		keys = {
			{ "<leader>tv", desc = "Toggle vertical terminal" },
			{ "<leader>th", desc = "Toggle horizontal terminal" },
			{ "<leader>tf", desc = "Toggle floating terminal" },
			{ "<leader>tt", desc = "Toggle terminal (default)" },
		},
		config = function()
			local toggleterm = require("toggleterm")
			local Terminal = require("toggleterm.terminal").Terminal

			toggleterm.setup({
				size = function(term)
					if term.direction == "horizontal" then
						return 15
					elseif term.direction == "vertical" then
						return vim.o.columns * 0.4
					end
				end,
				open_mapping = [[<leader>tt]],
				hide_numbers = true,
				shade_terminals = false,
				start_in_insert = true,
				insert_mappings = false,
				terminal_mappings = true,
				persist_size = true,
				persist_mode = false,
				direction = "horizontal",
				close_on_exit = true,
				shell = vim.o.shell,
				float_opts = {
					border = "single",
					width = function()
						return math.floor(vim.o.columns * 0.8)
					end,
					height = function()
						return math.floor(vim.o.lines * 0.8)
					end,
				},
			})

			local vertical_term = Terminal:new({ direction = "vertical" })
			local horizontal_term = Terminal:new({ direction = "horizontal" })
			local float_term = Terminal:new({ direction = "float" })

			vim.keymap.set("n", "<leader>tv", function()
				vertical_term:toggle()
			end, { desc = "Toggle vertical terminal" })

			vim.keymap.set("n", "<leader>th", function()
				horizontal_term:toggle()
			end, { desc = "Toggle horizontal terminal" })

			vim.keymap.set("n", "<leader>tf", function()
				float_term:toggle()
			end, { desc = "Toggle floating terminal" })

			-- Terminal mode navigation (consistent with window nav)
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { desc = "Focus left" })
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { desc = "Focus down" })
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { desc = "Focus up" })
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { desc = "Focus right" })
		end,
	},
}
