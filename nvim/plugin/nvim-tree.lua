vim.pack.add({ "https://github.com/nvim-tree/nvim-tree.lua" })

local icons_enabled = vim.g.icons_enabled

local config = {
	git = {
		enable = false,
	},
	update_focused_file = {
		enable = true,
		update_root = {
			enable = true,
		},
	},
	renderer = {
		indent_markers = {
			enable = false,
			inline_arrows = icons_enabled,
			icons = {
				corner = "└",
				edge = "│",
				item = "│",
				bottom = "─",
				none = " ",
			},
		},
		icons = {
			show = {
				file = icons_enabled,
				folder = icons_enabled,
				folder_arrow = icons_enabled,
				git = icons_enabled,
				modified = icons_enabled,
				hidden = icons_enabled,
				diagnostics = icons_enabled,
				bookmarks = icons_enabled,
			},
			web_devicons = {
				file = { enable = icons_enabled },
				folder = { enable = icons_enabled },
			},
		},
	},
}

require("nvim-tree").setup(config)

-- This function toggles the indent markers in nvim-tree
-- and preserves the tree's visibility and focus state.
local function toggle_indent_markers()
	local api = require("nvim-tree.api")
	local was_visible = api.tree.is_visible()
	local tree_had_focus = was_visible and api.tree.winid() == vim.api.nvim_get_current_win()

	config.renderer.indent_markers.enable = not config.renderer.indent_markers.enable
	require("nvim-tree").setup(config)

	if was_visible then
		api.tree.open()
		api.tree.reload()
		if tree_had_focus then
			local winid = api.tree.winid()
			if winid then
				vim.api.nvim_set_current_win(winid)
			end
		end
	end
end

vim.api.nvim_create_user_command("NvimTreeToggleIndent", toggle_indent_markers, {})
