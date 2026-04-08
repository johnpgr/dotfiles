local wezterm = require("wezterm")

local root = wezterm.config_dir
package.path = table.concat({
	root .. "/?.lua",
	root .. "/?/init.lua",
	package.path,
}, ";")

local config = wezterm.config_builder()
local act = wezterm.action
local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local platform = require("config.platform")
local theme = require("config.theme")

local regular_font = theme.regular_font()
local theme_mode = theme.read_theme_mode()

wezterm.add_to_config_reload_watch_list(theme.theme_mode_file)

config.front_end = "WebGpu"
config.font = regular_font
config.font_rules = theme.font_rules(regular_font)
config.max_fps = 165
config.default_prog = platform.default_prog()
config.font_size = 12.0
config.line_height = 1.2
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
-- config.window_decorations = "TITLE|RESIZE"
config.freetype_interpreter_version = 40
config.tab_max_width = 32
config.window_frame = theme.window_frame(theme_mode, regular_font)
config.cursor_blink_rate = 0
config.underline_position = "-3px"
config.underline_thickness = "1px"
config.color_scheme = theme.color_scheme(theme_mode)
config.colors = theme.tab_bar_colors(theme_mode)
config.scrollback_lines = 10000
config.enable_wayland = true
config.use_ime = false
-- config.window_background_opacity = 0.5
config.kde_window_background_blur = true

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.keys = {
	{ key = "Enter", mods = "ALT", action = act.DisableDefaultAssignment },
	{
		key = "+",
		mods = "ALT|SHIFT",
		action = act.SplitHorizontal({}),
	},
	{ key = "_", mods = "ALT|SHIFT", action = act.SplitVertical({}) },
	{ key = "W", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = false }) },
	{ key = "T", mods = "CTRL|SHIFT", action = act.SpawnTab("DefaultDomain") },
	{ key = "1", mods = "CTRL|ALT", action = act.ActivateTab(0) },
	{ key = "2", mods = "CTRL|ALT", action = act.ActivateTab(1) },
	{ key = "3", mods = "CTRL|ALT", action = act.ActivateTab(2) },
	{ key = "4", mods = "CTRL|ALT", action = act.ActivateTab(3) },
	{ key = "5", mods = "CTRL|ALT", action = act.ActivateTab(4) },
	{ key = "6", mods = "CTRL|ALT", action = act.ActivateTab(5) },
	{ key = "7", mods = "CTRL|ALT", action = act.ActivateTab(6) },
	{ key = "8", mods = "CTRL|ALT", action = act.ActivateTab(7) },
	{ key = "9", mods = "CTRL|ALT", action = act.ActivateTab(8) },
	{ key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
	{ key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
}

smart_splits.apply_to_config(config, {
	direction_keys = { "h", "j", "k", "l" },
	modifiers = {
		move = "CTRL",
		resize = "META",
	},
})

return config
