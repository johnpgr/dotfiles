-- GUI-specific configuration
-- Sourced from ginit.lua when any GUI attaches (UIEnter).

-- Enable right scrollbar for GUIs that render native scrollbars (gtk, win32, etc.)
-- Neovide renders these if it supports guioptions; currently it does not.
vim.o.guioptions = vim.o.guioptions .. 'r'

-- --------------------------------------------------------------------------
-- Neovide
-- --------------------------------------------------------------------------

if vim.g.neovide then
	vim.o.guifont = "Hack Nerd Font:h12"

	vim.g.neovide_refresh_rate = 165
	vim.g.neovide_opacity = 1.0

	vim.g.neovide_cursor_animation_length = 0
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_cursor_antialiasing = true
	vim.g.neovide_cursor_vfx_mode = ""

	vim.g.neovide_scroll_animation_length = 0.3
	vim.g.neovide_hide_mouse_when_typing = true

	vim.g.neovide_remember_window_size = true
	vim.g.neovide_remember_window_position = true

	vim.g.neovide_confirm_quit = true
	vim.g.neovide_no_idle = false

	vim.g.neovide_padding_top = 0
	vim.g.neovide_padding_bottom = 0
	vim.g.neovide_padding_right = 0
	vim.g.neovide_padding_left = 0

	vim.g.neovide_floating_shadow = false
	vim.g.neovide_floating_z_height = 0
	vim.g.neovide_light_angle_degrees = 0
	vim.g.neovide_light_radius = 0
end
