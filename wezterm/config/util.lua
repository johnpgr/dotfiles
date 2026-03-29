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

return M
