local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action
local util = require("config.util")

local M = {}

local home_dir = wezterm.home_dir
local workspace_scan_depth = 2
local ignored_dir_names = {
	[".git"] = true,
	[".Trash"] = true,
}

local function workspace_name_from_dir(path)
	local normalized_home = util.normalize_path(home_dir)
	local normalized_path = util.normalize_path(path)

	if normalized_path == normalized_home then
		return "home"
	end

	local home_prefix = normalized_home .. "/"
	if normalized_path:sub(1, #home_prefix) == home_prefix then
		return normalized_path:sub(#home_prefix + 1):gsub("[/\\]", ":")
	end

	return util.basename(path)
end

local function open_workspace_entries()
	local active_workspace = mux.get_active_workspace()
	local open_workspaces = {}
	local entries = {}

	for _, workspace in ipairs(mux.get_workspace_names()) do
		open_workspaces[workspace] = true
		table.insert(entries, {
			kind = "workspace",
			workspace = workspace,
			target = "",
			is_active = workspace == active_workspace,
		})
	end

	table.sort(entries, function(left, right)
		return left.workspace < right.workspace
	end)

	return entries, open_workspaces
end

local function collect_directory_entries(open_workspaces)
	local entries = {}
	local seen_workspaces = {}

	for workspace, _ in pairs(open_workspaces) do
		seen_workspaces[workspace] = true
	end

	local function scan_directory(root, depth)
		if depth == 0 then
			return
		end

		local children = util.safe_read_dir(root)
		if not children then
			return
		end

		for _, child in ipairs(children) do
			local child_name = util.basename(child)
			if not ignored_dir_names[child_name] then
				local nested = util.safe_read_dir(child)
				if nested then
					local workspace = workspace_name_from_dir(child)
					if workspace ~= "" and not seen_workspaces[workspace] then
						seen_workspaces[workspace] = true
						table.insert(entries, {
							kind = "directory",
							workspace = workspace,
							target = child,
							is_active = false,
						})
					end

					scan_directory(child, depth - 1)
				end
			end
		end
	end

	scan_directory(home_dir, workspace_scan_depth)

	table.sort(entries, function(left, right)
		if left.workspace == right.workspace then
			return left.target < right.target
		end
		return left.workspace < right.workspace
	end)

	return entries
end

local function workspace_choice_label(entry)
	local prefix = "dir:"
	if entry.kind == "workspace" then
		prefix = entry.is_active and "current:" or "open:"
	end

	local label = {
		{ Attribute = { Intensity = "Bold" } },
		{ Text = prefix },
		{ Attribute = { Intensity = "Normal" } },
		{ Text = " " .. entry.workspace },
	}

	if entry.target and entry.target ~= "" then
		table.insert(label, { Text = "  " .. entry.target })
	end

	return wezterm.format(label)
end

local function workspace_choices(mode)
	local open_entries, open_workspaces = open_workspace_entries()
	local entries = {}

	for _, entry in ipairs(open_entries) do
		table.insert(entries, entry)
	end

	if mode == "switch" then
		for _, entry in ipairs(collect_directory_entries(open_workspaces)) do
			table.insert(entries, entry)
		end
	end

	local choices = {}
	for _, entry in ipairs(entries) do
		table.insert(choices, {
			id = wezterm.json_encode({
				kind = entry.kind,
				workspace = entry.workspace,
				target = entry.target,
			}),
			label = workspace_choice_label(entry),
		})
	end

	return choices
end

local function parse_workspace_choice(id)
	local ok, decoded = pcall(wezterm.json_parse, id)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	return decoded
end

local function pane_ids_for_workspace(workspace)
	local pane_ids = {}

	for _, mux_window in ipairs(mux.all_windows()) do
		if mux_window:get_workspace() == workspace then
			for _, tab in ipairs(mux_window:tabs()) do
				for _, pane in ipairs(tab:panes()) do
					table.insert(pane_ids, pane:pane_id())
				end
			end
		end
	end

	return pane_ids
end

local function close_workspace(window, pane, workspace)
	local pane_ids = pane_ids_for_workspace(workspace)
	if #pane_ids == 0 then
		window:toast_notification("wezterm-workspaces", "No open panes found for workspace " .. workspace, nil, 3000)
		return
	end

	local current_pane_id = pane:pane_id()
	table.sort(pane_ids, function(left, right)
		if left == current_pane_id then
			return false
		end
		if right == current_pane_id then
			return true
		end
		return left < right
	end)

	for _, pane_id in ipairs(pane_ids) do
		local ok, _, stderr = util.run_wezterm_cli({ "kill-pane", "--pane-id", tostring(pane_id) })
		if not ok then
			if stderr and stderr ~= "" then
				wezterm.log_error(stderr)
			end
			window:toast_notification("wezterm-workspaces", "Failed to close workspace " .. workspace, nil, 4000)
			return
		end
	end

	window:toast_notification("wezterm-workspaces", "Closed workspace " .. workspace, nil, 2500)
end

function M.show_selector(window, pane, mode)
	local choices = workspace_choices(mode)
	if #choices == 0 then
		local message = mode == "close" and "No open workspaces to close" or "No workspaces or directories available"
		window:toast_notification("wezterm-workspaces", message, nil, 2500)
		return
	end

	local title = mode == "close" and "Close Workspace" or "Workspace Picker"
	local description = mode == "close"
			and "Select an open workspace to close."
		or "Open workspaces are listed first. Select one to switch, or choose a directory-backed workspace to create it."
	local fuzzy_description = mode == "close" and "Fuzzy close workspace: " or "Fuzzy find workspace or directory: "

	window:perform_action(
		act.InputSelector({
			title = title,
			description = description,
			fuzzy_description = fuzzy_description,
			fuzzy = true,
			choices = choices,
			action = wezterm.action_callback(function(inner_window, inner_pane, id, _)
				if not id then
					return
				end

				local entry = parse_workspace_choice(id)
				if not entry or type(entry.workspace) ~= "string" or entry.workspace == "" then
					inner_window:toast_notification("wezterm-workspaces", "Invalid workspace selection", nil, 3000)
					return
				end

				if mode == "close" then
					inner_window:perform_action(
						act.Confirmation({
							message = "Close workspace " .. entry.workspace .. "?",
							action = wezterm.action_callback(function(confirm_window, confirm_pane)
								close_workspace(confirm_window, confirm_pane, entry.workspace)
							end),
						}),
						inner_pane
					)
					return
				end

				local action
				if entry.kind == "directory" then
					action = act.SwitchToWorkspace({
						name = entry.workspace,
						spawn = {
							cwd = entry.target,
						},
					})
				else
					action = act.SwitchToWorkspace({
						name = entry.workspace,
					})
				end

				inner_window:perform_action(action, inner_pane)
			end),
		}),
		pane
	)
end

return M
