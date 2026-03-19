local wezterm = require "wezterm"
local config = wezterm.config_builder()
local regular_font = wezterm.font("Liberation Mono", { weight = "Regular", italic = false })

config.max_fps = 165
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.default_prog = { "zsh" }

config.font = regular_font
config.font_rules = {
	{
		intensity = "Normal",
		italic = false,
		font = regular_font,
	},
	{
		intensity = "Bold",
		italic = false,
		font = regular_font,
	},
	{
		intensity = "Normal",
		italic = true,
		font = regular_font,
	},
	{
		intensity = "Bold",
		italic = true,
		font = regular_font,
	},
}

config.font_size = 13.0
config.freetype_interpreter_version = 40
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.cursor_blink_rate = 0
config.color_scheme = "Gigavolt (base16)"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.underline_position = "-3px"
config.underline_thickness = "1px"

config.keys = {
	{ key = "+",          mods = "ALT|SHIFT",  action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
	{ key = "_",          mods = "ALT|SHIFT",  action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },

	{ key = "LeftArrow",  mods = "ALT",        action = wezterm.action.ActivatePaneDirection "Left" },
	{ key = "RightArrow", mods = "ALT",        action = wezterm.action.ActivatePaneDirection "Right" },
	{ key = "UpArrow",    mods = "ALT",        action = wezterm.action.ActivatePaneDirection "Up" },
	{ key = "DownArrow",  mods = "ALT",        action = wezterm.action.ActivatePaneDirection "Down" },

	{ key = "LeftArrow",  mods = "ALT|SHIFT",  action = wezterm.action.AdjustPaneSize { "Left", 3 } },
	{ key = "RightArrow", mods = "ALT|SHIFT",  action = wezterm.action.AdjustPaneSize { "Right", 3 } },
	{ key = "UpArrow",    mods = "ALT|SHIFT",  action = wezterm.action.AdjustPaneSize { "Up", 1 } },
	{ key = "DownArrow",  mods = "ALT|SHIFT",  action = wezterm.action.AdjustPaneSize { "Down", 1 } },

	{ key = "W",          mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane { confirm = false } },
	{ key = "T",          mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab "CurrentPaneDomain" },
	{ key = "1",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(0) },
	{ key = "2",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(1) },
	{ key = "3",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(2) },
	{ key = "4",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(3) },
	{ key = "5",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(4) },
	{ key = "6",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(5) },
	{ key = "7",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(6) },
	{ key = "8",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(7) },
	{ key = "9",          mods = "CTRL|ALT", action = wezterm.action.ActivateTab(8) },
	{ key = "Tab",        mods = "CTRL",       action = wezterm.action.ActivateTabRelative(1) },
	{ key = "Tab",        mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
}

return config
