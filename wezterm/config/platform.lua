local wezterm = require("wezterm")

local M = {}

M.is_windows = wezterm.target_triple:find("windows") ~= nil

function M.default_prog()
	if M.is_windows then
		return { "pwsh", "-NoLogo" }
	end

	return { "zsh" }
end

return M
