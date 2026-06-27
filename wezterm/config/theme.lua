local wezterm = require("wezterm")
local prompt = require("config.prompt")

local M = {}

local config_dir = wezterm.config_dir:gsub("\\", "/"):gsub("/+$", "")
local config_parent = config_dir:match("^(.*)/[^/]+$")
local home_dotfiles = wezterm.home_dir:gsub("\\", "/"):gsub("/+$", "") .. "/.dotfiles"
local state_dir = config_parent and config_parent:match("/%.dotfiles$") and config_parent or home_dotfiles
M.theme_mode_file = state_dir .. "/.theme_state"
M.font_family_file = state_dir .. "/.wezterm_font"
M.dark_color_scheme_file = state_dir .. "/.wezterm_dark_theme"
M.light_color_scheme_file = state_dir .. "/.wezterm_light_theme"
M.default_dark_color_scheme = "GruvboxDarkHard"
M.default_light_color_scheme = "Alabaster"
M.default_font_family = "Consolas"
M.enable_bold_font = true

local function ensure_file(path, value)
	local file = io.open(path, "r")
	if file then
		file:close()
		return
	end

	file = io.open(path, "w")
	if not file then
		wezterm.log_warn("unable to initialize prompt state: " .. path)
		return
	end

	file:write(value, "\n")
	file:close()
end

function M.ensure_state_files()
	ensure_file(M.theme_mode_file, "dark")
	ensure_file(M.font_family_file, M.default_font_family)
	ensure_file(M.dark_color_scheme_file, M.default_dark_color_scheme)
	ensure_file(M.light_color_scheme_file, M.default_light_color_scheme)
end

function M.read_font_family()
	return prompt.read_file(M.font_family_file, M.default_font_family)
end

function M.regular_font()
	return wezterm.font(M.read_font_family(), { weight = "Regular", italic = false })
end

function M.bold_font()
	return wezterm.font(M.read_font_family(), { weight = "Bold", italic = false })
end

function M.italic_font()
	return wezterm.font(M.read_font_family(), { weight = "Regular", italic = true })
end

function M.bold_italic_font()
	return wezterm.font(M.read_font_family(), { weight = "Bold", italic = true })
end

function M.font_rules()
	local regular = M.regular_font()

	if not M.enable_bold_font then
		return {
			{
				intensity = "Normal",
				italic = false,
				font = regular,
			},
			{
				intensity = "Bold",
				italic = false,
				font = regular,
			},
			{
				intensity = "Normal",
				italic = true,
				font = regular,
			},
			{
				intensity = "Bold",
				italic = true,
				font = regular,
			},
		}
	end

	return {
		{
			intensity = "Normal",
			italic = false,
			font = regular,
		},
		{
			intensity = "Bold",
			italic = false,
			font = M.bold_font(),
		},
		{
			intensity = "Normal",
			italic = true,
			font = M.italic_font(),
		},
		{
			intensity = "Bold",
			italic = true,
			font = M.bold_italic_font(),
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
