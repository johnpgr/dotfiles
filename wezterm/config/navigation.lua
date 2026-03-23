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

local function basename(path)
	if not path or path == "" then
		return nil
	end

	return path:match("([^/\\]+)$") or path
end

local function looks_like_vim_process(name)
	if not name or name == "" then
		return false
	end

	local normalized = basename(name):lower():gsub("%.exe$", "")
	return normalized:match("^g?%.?(view|n?vim?x?)(%-wrapped)?(diff)?$") ~= nil
end

local function is_vim(pane)
	if pane:get_user_vars().IS_NVIM == "1" then
		return true
	end

	if pane:is_alt_screen_active() then
		return true
	end

	local process_info = pane:get_foreground_process_info()
	if not process_info then
		return false
	end

	return looks_like_vim_process(process_info.name) or looks_like_vim_process(process_info.executable)
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
