-- Misc: shared dependencies, pickers (fff + mini.pick),
-- scope, neovim-project, mise

local is_neovide = vim.g.neovide ~= nil
local is_windows = vim.fn.has("win32") == 1

return {
	-- Icons (LSP completion kinds + devicons API for oil.nvim)
	{
		"nvim-mini/mini.icons",
		lazy = false,
		config = function()
			require("mini.icons").setup({
				lsp = {
					["function"] = { glyph = "󰆧" },
				},
			})
			MiniIcons.mock_nvim_web_devicons()
		end,
	},

	-- FFF (Fast File Finder)
	{
		"dmtrKovalenko/fff.nvim",
		event = "VeryLazy",
		build = function()
			pcall(function()
				require("fff.download").download_or_build_binary()
			end)
		end,
	},

	-- Mini.pick (picker UI)
	{
		"nvim-mini/mini.pick",
		version = false,
		event = "VeryLazy",
		config = function()
			local pick = require("mini.pick")
			pick.setup({
				window = {
					config = {
						border = "single",
					},
				},
			})
			vim.ui.select = pick.ui_select
		end,
	},

	-- Neovim Project (project switching, Neovide only)
	{
		"coffebar/neovim-project",
		lazy = false,
		enabled = is_neovide,
		dependencies = { "Shatur/neovim-session-manager" },
		opts = {
			projects = {
				"~/dev/*",
				"~/.dotfiles",
			},
			last_session_on_startup = false,
			dashboard_mode = true,
		},
		keys = {
			{
				"<leader>pp",
				function()
					require("mini.pick").registry.neovim_project_history()
				end,
				desc = "Project history",
			},
			{
				"<leader>pd",
				function()
					require("mini.pick").registry.neovim_project_discover()
				end,
				desc = "Discover projects",
			},
		},
		init = function()
			vim.opt.sessionoptions:append("globals")
		end,
		config = function(_, opts)
			require("neovim-project").setup(opts)

			local pick = require("mini.pick")
			local path = require("neovim-project.utils.path")
			local history = require("neovim-project.utils.history")
			local project = require("neovim-project.project")

			local neotree_restore_group =
				vim.api.nvim_create_augroup("neovim-project-neotree-restore", { clear = true })
			vim.api.nvim_create_autocmd("User", {
				pattern = "SessionLoadPost",
				group = neotree_restore_group,
				callback = function()
					local ok_state, neotree_state = pcall(require, "neovim-project.utils.neo-tree")
					if not ok_state or neotree_state.dirs_to_restore == nil or #neotree_state.dirs_to_restore == 0 then
						return
					end
					vim.schedule(function()
						local ok_command, neotree_command = pcall(require, "neo-tree.command")
						if not ok_command then
							return
						end
						neotree_command.execute({
							action = "show",
							source = "filesystem",
							position = "left",
							reveal_force_cwd = true,
						})
					end)
				end,
			})

			local function get_picker_entries(discover)
				local results
				if discover then
					results = path.get_all_projects_with_sorting()
				else
					results = history.get_recent_projects()
					results = path.fix_symlinks_for_history(results)
					for i = 1, math.floor(#results / 2) do
						results[i], results[#results - i + 1] = results[#results - i + 1], results[i]
					end
				end
				return results
			end

			pick.registry.neovim_project_history = function()
				local results = get_picker_entries(false)
				if #results == 0 then
					vim.notify("No recent projects", vim.log.levels.INFO)
					return
				end
				local chosen = pick.start({
					source = {
						items = results,
						name = "Project History",
					},
				})
				if chosen then
					project.switch_project(chosen)
				end
			end

			pick.registry.neovim_project_discover = function()
				local results = get_picker_entries(true)
				if #results == 0 then
					vim.notify("No projects found", vim.log.levels.INFO)
					return
				end
				local chosen = pick.start({
					source = {
						items = results,
						name = "Discover Projects",
					},
				})
				if chosen then
					project.switch_project(chosen)
				end
			end
		end,
	},
}
