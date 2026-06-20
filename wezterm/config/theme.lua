local wezterm = require("wezterm")
local prompt = require("config.prompt")

local M = {}

M.theme_mode_file = wezterm.home_dir .. "/.dotfiles/.theme_state"
M.font_family_file = wezterm.home_dir .. "/.dotfiles/.wezterm_font"
M.dark_color_scheme_file = wezterm.home_dir .. "/.dotfiles/.wezterm_dark_theme"
M.light_color_scheme_file = wezterm.home_dir .. "/.dotfiles/.wezterm_light_theme"
M.default_dark_color_scheme = "GruvboxDarkHard"
M.default_light_color_scheme = "Alabaster"
M.default_font_family = "BerkeleyMono Nerd Font"

function M.read_font_family()
	return prompt.read_file(M.font_family_file, M.default_font_family)
end

function M.regular_font()
	return wezterm.font(M.read_font_family(), { weight = "Regular", italic = false })
end

function M.font_rules(font)
	return {
		{
			intensity = "Normal",
			italic = false,
			font = font,
		},
		{
			intensity = "Bold",
			italic = false,
			font = font,
		},
		{
			intensity = "Normal",
			italic = true,
			font = font,
		},
		{
			intensity = "Bold",
			italic = true,
			font = font,
		},
	}
end

function M.read_theme_mode()
	local mode = prompt.read_file(M.theme_mode_file, "dark")
	if mode == "light" then
		return "light"
	end

	return "dark"
end

function M.read_dark_color_scheme()
	return prompt.read_file(M.dark_color_scheme_file, M.default_dark_color_scheme)
end

function M.read_light_color_scheme()
	return prompt.read_file(M.light_color_scheme_file, M.default_light_color_scheme)
end

function M.color_scheme(mode)
	if mode == "light" then
		return M.read_light_color_scheme()
	end

	return M.read_dark_color_scheme()
end

function M.window_frame(mode, font)
	local bg = mode == "light" and "#d6d5d4" or "#11151b"
	local btn_fg = mode == "light" and "#4a4543" or "#7f8da1"
	local btn_hover_bg = mode == "light" and "#f7f7f7" or "#1a212a"
	local btn_hover_fg = mode == "light" and "#3a3432" or "#b8c7dd"

	return {
		font = font,
		font_size = 10.0,
		active_titlebar_bg = bg,
		inactive_titlebar_bg = bg,
		button_fg = btn_fg,
		button_bg = bg,
		button_hover_fg = btn_hover_fg,
		button_hover_bg = btn_hover_bg,
	}
end

function M.tab_bar_colors(mode)
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
					bg_color = "#d6d5d4",
					fg_color = "#4a4543",
				},
			},
		}
	end

	return {
		tab_bar = {
			background = "#202020",
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
				bg_color = "#11151b",
				fg_color = "#7f8da1",
			},
			new_tab_hover = {
				bg_color = "#11151b",
				fg_color = "#b8c7dd",
			},
		},
	}
end

return M
