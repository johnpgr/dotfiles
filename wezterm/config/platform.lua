local wezterm = require("wezterm")

local M = {}

M.is_windows = wezterm.target_triple:find("windows") ~= nil

function M.default_prog()
	if M.is_windows then
		return { "pwsh", "-NoLogo" }
	end

	return { "zsh" }
end

function M.configure_unix_domain(config)
	if M.is_windows then
		return
	end

	config.term = "wezterm"
	config.unix_domains = {
		{
			name = "unix",
		},
	}
	config.default_gui_startup_args = { "connect", "unix" }
end

return M
