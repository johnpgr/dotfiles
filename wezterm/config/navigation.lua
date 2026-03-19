local wezterm = require("wezterm")

local M = {}

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

local function is_vim(pane)
	local process_info = pane:get_foreground_process_info()
	local process_name = process_info and process_info.name

	return process_name == "nvim" or process_name == "vim" or process_name == "nvim.exe" or process_name == "vim.exe"
end

function M.split_nav(action, key)
	local mods = action == "resize" and "ALT" or "CTRL"

	return {
		key = key,
		mods = mods,
		action = wezterm.action_callback(function(window, pane)
			if is_vim(pane) then
				window:perform_action({
					SendKey = { key = key, mods = mods },
				}, pane)
				return
			end

			if action == "resize" then
				window:perform_action({
					AdjustPaneSize = { direction_keys[key], 3 },
				}, pane)
				return
			end

			window:perform_action({
				ActivatePaneDirection = direction_keys[key],
			}, pane)
		end),
	}
end

return M
