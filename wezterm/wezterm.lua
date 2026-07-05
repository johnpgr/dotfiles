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
local font_picker = require("config.font_picker")
local open_in_nvim = require("config.open_in_nvim")
local platform = require("config.platform")
local theme = require("config.theme")
local theme_picker = require("config.theme_picker")

-- Set to true to use real Bold/Italic font weights instead of Regular for all styles.
theme.enable_bold_font = false

local regular_font = theme.regular_font()
local theme_mode = theme.read_theme_mode()

theme.ensure_state_files()
wezterm.add_to_config_reload_watch_list(theme.theme_mode_file)
wezterm.add_to_config_reload_watch_list(theme.font_family_file)
wezterm.add_to_config_reload_watch_list(theme.dark_color_scheme_file)
wezterm.add_to_config_reload_watch_list(theme.light_color_scheme_file)

if not platform.is_windows then
    config.term = "wezterm"
end

config.front_end = "WebGpu"
config.font = regular_font
config.font_rules = theme.font_rules(regular_font.font[1].family)
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.max_fps = 165
config.default_prog = platform.default_prog()
config.default_cwd = platform.default_cwd()
config.set_environment_variables = platform.environment_variables()
config.font_size = 11
config.line_height = 1
config.cell_width = 1
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = not platform.is_windows
config.use_fancy_tab_bar = platform.is_windows
config.window_decorations = platform.window_decorations()
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
config.window_close_confirmation = "NeverPrompt"

config.window_padding = {
    left = 0,
    right = 0,
    top = 6,
    bottom = 0,
}

config.keys = {
    { key = "Enter", mods = "ALT",        action = act.DisableDefaultAssignment },
    {
        key = "+",
        mods = "ALT|SHIFT",
        action = act.SplitHorizontal({}),
    },
    { key = "_",     mods = "ALT|SHIFT",  action = act.SplitVertical({}) },
    { key = "W",     mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = false }) },
    { key = "T",     mods = "CTRL|SHIFT", action = act.SpawnTab("DefaultDomain") },
    { key = "1",     mods = "CTRL|ALT",   action = act.ActivateTab(0) },
    { key = "2",     mods = "CTRL|ALT",   action = act.ActivateTab(1) },
    { key = "3",     mods = "CTRL|ALT",   action = act.ActivateTab(2) },
    { key = "4",     mods = "CTRL|ALT",   action = act.ActivateTab(3) },
    { key = "5",     mods = "CTRL|ALT",   action = act.ActivateTab(4) },
    { key = "6",     mods = "CTRL|ALT",   action = act.ActivateTab(5) },
    { key = "7",     mods = "CTRL|ALT",   action = act.ActivateTab(6) },
    { key = "8",     mods = "CTRL|ALT",   action = act.ActivateTab(7) },
    { key = "9",     mods = "CTRL|ALT",   action = act.ActivateTab(8) },
    { key = "Tab",   mods = "CTRL",       action = act.ActivateTabRelative(1) },
    { key = "Tab",   mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "z",     mods = "ALT",        action = act.TogglePaneZoomState },
    { key = "phys:F", mods = "ALT|SHIFT",  action = font_picker.action() },
    { key = "phys:T", mods = "ALT|SHIFT",  action = theme_picker.action() },
}

config.mouse_bindings = {
    {
        event = { Down = { streak = 1, button = { WheelUp = 1 } } },
        mods = "CTRL",
        action = act.IncreaseFontSize,
    },
    {
        event = { Down = { streak = 1, button = { WheelDown = 1 } } },
        mods = "CTRL",
        action = act.DecreaseFontSize,
    },
}

smart_splits.apply_to_config(config, {
    direction_keys = { "h", "j", "k", "l" },
    modifiers = {
        move = "CTRL",
        resize = "META",
    },
})

open_in_nvim.apply_to_config(config)
theme_picker.apply_to_config(config)

return config
