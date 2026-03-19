local wezterm = require "wezterm"
local config = wezterm.config_builder()
local regular_font = wezterm.font("Liberation Mono", { weight = "Regular", italic = false })
local theme_mode_file = wezterm.home_dir .. "/.dotfiles/.theme_state"
local dark_color_scheme = "Gigavolt (base16)"
local light_color_scheme = "3024 Day"

local function read_theme_mode()
	local file, err = io.open(theme_mode_file, "r")
	if not file then
		if err and not err:match("No such file") then
			wezterm.log_warn("unable to read theme state: " .. err)
		end
		return "dark"
	end

	local mode = file:read("*all")
	file:close()
	mode = mode and mode:match("^%s*(.-)%s*$") or ""

	if mode == "light" then
		return "light"
	end

	return "dark"
end

local function is_vim(pane)
	local process_info = pane:get_foreground_process_info()
	local process_name = process_info and process_info.name

	return process_name == "nvim" or process_name == "vim"
end

local direction_keys = {
	Left = "h",
	Down = "j",
	Up = "k",
	Right = "l",
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(action, key)
	local mods = action == "resize" and "ALT" or "CTRL"

	return {
		key = key,
		mods = mods,
		action = wezterm.action_callback(function(win, pane)
			if is_vim(pane) then
				win:perform_action({
					SendKey = { key = key, mods = mods },
				}, pane)
				return
			end

			if action == "resize" then
				win:perform_action({
					AdjustPaneSize = { direction_keys[key], 3 },
				}, pane)
				return
			end

			win:perform_action({
				ActivatePaneDirection = direction_keys[key],
			}, pane)
		end),
	}
end

local function tab_bar_colors(mode)
	if mode == "light" then
		return {
			tab_bar = {
				background = "#d6d5d4",
				active_tab = {
					bg_color = "#f7f7f7",
					fg_color = "#4a4543",
					intensity = "Bold",
				},
				inactive_tab = {
					bg_color = "#a5a2a2",
					fg_color = "#4a4543",
				},
				inactive_tab_hover = {
					bg_color = "#f7f7f7",
					fg_color = "#3a3432",
				},
				new_tab = {
					bg_color = "#d6d5d4",
					fg_color = "#807d7c",
				},
				new_tab_hover = {
					bg_color = "#f7f7f7",
					fg_color = "#4a4543",
				},
			},
		}
	end

	return {
		tab_bar = {
			background = "#11151b",
			active_tab = {
				bg_color = "#1c222b",
				fg_color = "#e9f1ff",
				intensity = "Bold",
			},
			inactive_tab = {
				bg_color = "#161b22",
				fg_color = "#7f8da1",
			},
			inactive_tab_hover = {
				bg_color = "#1a212a",
				fg_color = "#b8c7dd",
			},
			new_tab = {
				bg_color = "#161b22",
				fg_color = "#7f8da1",
			},
			new_tab_hover = {
				bg_color = "#1a212a",
				fg_color = "#b8c7dd",
			},
		},
	}
end

local theme_mode = read_theme_mode()

wezterm.add_to_config_reload_watch_list(theme_mode_file)

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

config.max_fps = 165
config.animation_fps = 165
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.default_prog = { "zsh" }
config.term = "wezterm"
config.font_size = 12.0
config.freetype_interpreter_version = 40
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.cursor_blink_rate = 0
config.underline_position = "-3px"
config.underline_thickness = "1px"
config.color_scheme = theme_mode == "light" and light_color_scheme or dark_color_scheme
config.colors = tab_bar_colors(theme_mode)

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.keys = {
	{ key = "+",          mods = "ALT|SHIFT",  action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
	{ key = "_",          mods = "ALT|SHIFT",  action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	split_nav("resize", "h"),
	split_nav("resize", "j"),
	split_nav("resize", "k"),
	split_nav("resize", "l"),

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
