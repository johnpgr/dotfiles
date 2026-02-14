---@type Wezterm
local wezterm = require("wezterm")

---@type Config
local config = wezterm.config_builder()

config.max_fps = 165
config.cursor_blink_rate = 0
config.term = "wezterm"
config.font = wezterm.font("Consolas Nerd Font")
config.font_rules = {
	{
		intensity = "Bold",
		italic = false,
		font = wezterm.font("Consolas Nerd Font", { weight = "Regular" }),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font("Consolas Nerd Font", { weight = "Regular", style = "Italic" }),
	},
}

config.bold_brightens_ansi_colors = false
config.font_size = 14
config.freetype_interpreter_version = 40
config.hide_tab_bar_if_only_one_tab = true
config.color_scheme = "Default Dark (base16)"
config.window_close_confirmation = "NeverPrompt" 

config.colors = {
	-- background = "#1d2021",
    background = "#0e1415",
    cursor_bg = "#00d850"
}

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

return config
