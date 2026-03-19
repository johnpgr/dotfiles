local wezterm = require("wezterm")
local platform = require("config.platform")

local M = {}

function M.trim_path(path)
	return path:gsub("[/\\]+$", "")
end

function M.normalize_path(path)
	return M.trim_path(path):gsub("\\", "/")
end

function M.basename(path)
	local trimmed = M.trim_path(path)
	return trimmed:match("([^/\\]+)$") or trimmed
end

function M.cwd_path(pane)
	local cwd = pane and pane:get_current_working_dir()
	if not cwd then
		return ""
	end

	if type(cwd) == "string" then
		if cwd:match("^file://") then
			local path = cwd:gsub("^file://[^/]*", "")
			path = path:gsub("%%(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
			if platform.is_windows and path:match("^/[A-Za-z]:") then
				return path:sub(2)
			end
			return path
		end

		return cwd
	end

	return cwd.file_path or cwd.path or tostring(cwd)
end

function M.safe_read_dir(path)
	local ok, entries = pcall(wezterm.read_dir, path)
	if not ok or type(entries) ~= "table" then
		return nil
	end

	table.sort(entries)
	return entries
end

local function wezterm_cli_candidates()
	local executable_dir = M.trim_path(wezterm.executable_dir or "")
	local candidates = {}

	if executable_dir ~= "" then
		if platform.is_windows then
			table.insert(candidates, executable_dir .. "\\wezterm.exe")
			table.insert(candidates, executable_dir .. "\\wezterm-gui.exe")
		else
			table.insert(candidates, executable_dir .. "/wezterm")
			table.insert(candidates, executable_dir .. "/wezterm-gui")
		end
	end

	if platform.is_windows then
		table.insert(candidates, "wezterm.exe")
	end

	table.insert(candidates, "wezterm")
	return candidates
end

function M.run_wezterm_cli(args)
	local errors = {}

	for _, executable in ipairs(wezterm_cli_candidates()) do
		local command = { executable, "cli" }
		if not platform.is_windows then
			table.insert(command, "--prefer-mux")
		end
		for _, arg in ipairs(args) do
			table.insert(command, arg)
		end

		local ok, stdout, stderr = wezterm.run_child_process(command)
		if ok then
			return true, stdout, stderr
		end

		if stderr and stderr ~= "" then
			table.insert(errors, stderr)
		end
	end

	return false, "", table.concat(errors, "\n")
end

return M
