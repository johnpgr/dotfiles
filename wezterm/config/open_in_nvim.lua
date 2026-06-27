local wezterm = require("wezterm")
local platform = require("config.platform")
local util = require("config.util")

local act = wezterm.action
local M = {}

local SCHEME = "nvim-open"

local diagnostic_pattern = [[\b((?:[A-Za-z]:[\\/][A-Za-z0-9_ .\\/()+-]*|(?:\./|\.\./|/)?[A-Za-z0-9_./+-][A-Za-z0-9_./+-]*)\.[A-Za-z0-9_+-]+):(\d+):(\d+)]]

local function log_info(message)
	wezterm.log_info("[open_in_nvim] " .. message)
end

local function log_error(message)
	wezterm.log_error("[open_in_nvim] " .. message)
end

local function home_dir()
	return os.getenv("HOME") or wezterm.home_dir or ""
end

local function local_app_data_dir()
	local local_app_data = os.getenv("LOCALAPPDATA")
	if local_app_data and local_app_data ~= "" then
		return local_app_data
	end

	return home_dir() .. "/AppData/Local"
end

local function dir_for_io(path)
	if platform.is_windows then
		return path:gsub("/", "\\")
	end

	return path
end

local function add_unique(list, seen, path)
	if not path or path == "" or seen[path] then
		return
	end

	seen[path] = true
	table.insert(list, path)
end

local function registry_dirs()
	local dirs = {}
	local seen = {}
	local xdg_state_home = os.getenv("XDG_STATE_HOME")
	if xdg_state_home and xdg_state_home ~= "" then
		add_unique(dirs, seen, xdg_state_home .. "/nvim/wezterm-open-in-nvim")
	end

	if platform.is_windows then
		add_unique(dirs, seen, local_app_data_dir() .. "/nvim-data/wezterm-open-in-nvim")
	end

	add_unique(dirs, seen, home_dir() .. "/.local/state/nvim/wezterm-open-in-nvim")
	return dirs
end

local function is_absolute_path(path)
	return path:match("^/")
		or path:match("^[A-Za-z]:[/\\]")
		or path:match("^\\\\")
		or path:match("^//")
end

local function path_exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end

	return false
end

local function notify(window, message)
	log_info(message)
	window:toast_notification("open in nvim", message, nil, 4000)
end

local function url_decode(text)
	return (text:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function url_encode(text)
	return (text:gsub("[^A-Za-z0-9_./~:-]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function normalize(path)
	return util.normalize_path(path)
end

local function join_path(base, path)
	if is_absolute_path(path) then
		return normalize(path)
	end

	return normalize(base .. "/" .. path)
end

local function registry_path(dir, pid)
	return dir_for_io(dir) .. (platform.is_windows and "\\" or "/") .. tostring(pid) .. ".server"
end

local function list_registry_entries(dir)
	local io_dir = dir_for_io(dir)
	local separator = platform.is_windows and "\\" or "/"
	local glob_pattern = io_dir .. separator .. "*.server"
	local ok, entries = pcall(wezterm.glob, glob_pattern)
	if ok and type(entries) == "table" and #entries > 0 then
		return entries
	end

	entries = util.safe_read_dir(io_dir)
	if entries and #entries > 0 then
		return entries
	end

	if platform.is_windows then
		local handle = io.popen('cmd /c dir /b "' .. io_dir .. '\\*.server" 2>nul')
		if handle then
			local result = {}
			for name in handle:lines() do
				if name:match("%.server$") then
					table.insert(result, io_dir .. "\\" .. name)
				end
			end
			handle:close()
			if #result > 0 then
				return result
			end
		end
	end

	return {}
end

local function nvim_command()
	if not platform.is_windows then
		return "nvim"
	end

	local candidates = {
		"C:\\Program Files\\Neovim\\bin\\nvim.exe",
		"C:\\msys64\\ucrt64\\bin\\nvim.exe",
		"C:\\msys64\\mingw64\\bin\\nvim.exe",
		"C:\\msys64\\usr\\bin\\nvim.exe",
	}

	for _, candidate in ipairs(candidates) do
		if path_exists(candidate) then
			return candidate
		end
	end

	return "C:\\msys64\\ucrt64\\bin\\nvim.exe"
end

local function path_for_nvim(path)
	path = normalize(path)
	if platform.is_windows then
		return path:gsub("/", "\\")
	end

	return path
end

local function nvim_error_message(stdout, stderr)
	local message = stderr or stdout or ""
	if message == "" then
		return nil
	end

	if message:match("E%d+:") then
		return message
	end

	return nil
end

local function run_nvim_client(args)
	local success, stdout, stderr = wezterm.run_child_process(args)
	if not success then
		return false, nvim_error_message(stdout, stderr) or stderr or stdout or "nvim client failed"
	end

	local error_message = nvim_error_message(stdout, stderr)
	if error_message then
		return false, error_message
	end

	return true, nil
end

local function read_registry_file(path, label)
	local file, err = io.open(path, "r")
	if not file then
		log_info(("no registry for %s path=%s error=%s"):format(label, path, tostring(err)))
		return nil
	end

	local contents = file:read("*a")
	file:close()

	if not contents or contents == "" then
		log_info(("empty registry for %s path=%s"):format(label, path))
		return nil
	end

	local server, cwd = contents:match("^([^\n]+)\n([^\n]+)")
	if not server or not cwd then
		log_error(("invalid registry for %s path=%s contents=%q"):format(label, path, contents))
		return nil
	end

	log_info(("registry %s server=%s cwd=%s"):format(label, server, cwd))
	return {
		server = server,
		cwd = normalize(cwd),
	}
end

local function read_all_registries()
	local registries = {}

	for _, dir in ipairs(registry_dirs()) do
		local entries = list_registry_entries(dir)
		for _, entry in ipairs(entries) do
			if entry:match("%.server$") then
				local path = entry
				if not is_absolute_path(path) then
					local separator = platform.is_windows and "\\" or "/"
					path = dir_for_io(dir) .. separator .. path
				end
				local registry = read_registry_file(path, "file=" .. util.basename(path))
				if registry then
					table.insert(registries, registry)
				end
			end
		end
	end

	log_info(("loaded %d registry file(s)"):format(#registries))
	return registries
end

local function path_score(cwd, target)
	cwd = normalize(cwd)
	target = normalize(target)

	if cwd == "" then
		return 0
	end

	if target == cwd or target:sub(1, #cwd + 1) == cwd .. "/" then
		return #cwd
	end

	return 0
end

local function registry_pid(registry)
	return tonumber(registry.server:match("nvim%.(%d+)%.") or "0") or 0
end

local function matching_registries(target_path, registries)
	local matching = {}

	for _, registry in ipairs(registries) do
		if path_score(registry.cwd, target_path) > 0 then
			table.insert(matching, registry)
		end
	end

	table.sort(matching, function(a, b)
		return registry_pid(a) > registry_pid(b)
	end)

	return matching
end

local function find_other_pane_in_tab(tab, source_pane_id)
	for _, item in ipairs(tab:panes_with_info()) do
		if item.pane:pane_id() ~= source_pane_id then
			return item.pane
		end
	end

	return nil
end

local function activation_target(window, source_pane)
	local mux_window = window:mux_window()
	if not mux_window then
		return nil
	end

	local source_pane_id = source_pane:pane_id()

	for _, tab_info in ipairs(mux_window:tabs_with_info()) do
		for _, item in ipairs(tab_info.tab:panes_with_info()) do
			if item.pane:pane_id() == source_pane_id then
				local other_pane = find_other_pane_in_tab(tab_info.tab, source_pane_id)
				if other_pane then
					return {
						pane = other_pane,
						tab = tab_info.tab,
						tab_index = tab_info.index,
					}
				end
			end
		end
	end

	return nil
end

local function activate_target(window, source_pane, target)
	if not target then
		return
	end

	if target.tab_index then
		window:perform_action(act.ActivateTab(target.tab_index), source_pane)
	end

	if target.tab and target.tab.activate then
		pcall(function()
			target.tab:activate()
		end)
	end

	target.pane:activate()
	log_info(("activated tab_index=%s pane_id=%s"):format(tostring(target.tab_index), tostring(target.pane:pane_id())))
end

local function remote_open(server, path, line, column)
	local nvim = nvim_command()
	local nvim_path = path_for_nvim(path)

	local success, stderr = run_nvim_client({
		nvim,
		"--headless",
		"--server",
		server,
		"--remote",
		nvim_path,
	})
	if not success then
		return false, stderr
	end

	success, stderr = run_nvim_client({
		nvim,
		"--headless",
		"--server",
		server,
		"--remote-expr",
		("cursor(%d,%d)"):format(line, column),
	})
	if not success then
		return false, stderr
	end

	return true, nil
end

local function open_in_nvim(window, pane, raw_path, raw_line, raw_column)
	local cwd = normalize(util.cwd_path(pane))
	local path = join_path(cwd, url_decode(raw_path))
	local line = tonumber(raw_line) or 1
	local column = tonumber(raw_column) or 1
	log_info(("open request raw=%s:%s:%s cwd=%s resolved=%s"):format(raw_path, raw_line, raw_column, cwd, path))

	local registries = read_all_registries()
	if #registries == 0 then
		notify(window, "no Neovim registry files found")
		return false
	end

	local candidates = matching_registries(path, registries)
	if #candidates == 0 then
		notify(window, "no Neovim instance for this project")
		return false
	end

	local last_error = nil
	for _, registry in ipairs(candidates) do
		log_info(("trying server=%s cwd=%s"):format(registry.server, registry.cwd))
		local success, stderr = remote_open(registry.server, path, line, column)
		if success then
			activate_target(window, pane, activation_target(window, pane))
			return true
		end

		last_error = stderr
		log_error("remote open failed: " .. tostring(stderr or ""))
	end

	notify(window, "failed to open in Neovim: " .. tostring(last_error or "unknown error"))
	return false
end

local function parse_location(text)
	local line, column = text:match(":(%d+):(%d+)$")
	if not line then
		return nil
	end

	local path = text:sub(1, #text - #line - #column - 2)
	if path == "" then
		return nil
	end

	return path, line, column
end

local function parse_uri(uri)
	log_info("open-uri uri=" .. uri)
	local prefix = SCHEME .. ":"
	if uri:sub(1, #prefix) ~= prefix then
		return nil
	end

	local payload = url_decode(uri:sub(#prefix + 1))
	local line, column = payload:match(":(%d+):(%d+)$")
	if not line then
		log_error("failed to parse nvim uri: " .. uri)
		return nil
	end

	local path = payload:sub(1, #payload - #line - #column - 2)
	if path == "" then
		log_error("empty path in nvim uri: " .. uri)
		return nil
	end

	log_info(("parsed uri path=%s line=%s column=%s"):format(path, line, column))
	return path, line, column
end

local act_callback = wezterm.action_callback

local function schedule_open_in_nvim(window, pane, path, line, column)
	window:perform_action(
		act_callback(function(win, active_pane)
			open_in_nvim(win, active_pane, path, line, column)
		end),
		pane
	)
end

local function handle_open_uri(window, pane, uri)
	local prefix = SCHEME .. ":"
	if uri:sub(1, #prefix) ~= prefix then
		return nil
	end

	local path, line, column = parse_uri(uri)
	if not path then
		notify(window, "failed to parse file location link")
		return false
	end

	schedule_open_in_nvim(window, pane, path, line, column)
	return false
end

function M.apply_to_config(config)
	if platform.is_windows then
		return
	end

	local rules = wezterm.default_hyperlink_rules()
	table.insert(rules, 1, {
		regex = diagnostic_pattern,
		format = SCHEME .. ":$1:$2:$3",
	})
	config.hyperlink_rules = rules

	config.quick_select_patterns = config.quick_select_patterns or {}
	table.insert(config.quick_select_patterns, diagnostic_pattern)

	config.keys = config.keys or {}
	table.insert(config.keys, {
		key = "G",
		mods = "CTRL|SHIFT",
		action = act.QuickSelectArgs({
			patterns = { diagnostic_pattern },
			action = wezterm.action_callback(function(window, pane)
				local selection = window:get_selection_text_for_pane(pane)
				log_info("quick select selection=" .. selection)
				local path, line, column = parse_location(selection)
				if path then
					open_in_nvim(window, pane, url_encode(path), line, column)
				else
					notify(window, "selection did not match diagnostic pattern")
				end
			end),
		}),
	})

	wezterm.on("open-uri", handle_open_uri)
end

return M
