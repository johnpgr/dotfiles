local wezterm = require("wezterm")
local util = require("config.util")

local act = wezterm.action
local M = {}

local SCHEME = "nvim-open"

local diagnostic_pattern = [[\b((?:\./|\.\./|/)?[A-Za-z0-9_./+-][A-Za-z0-9_./+-]*\.[A-Za-z0-9_+-]+):(\d+):(\d+)]]
local diagnostic_lua_pattern = [[^(.+):(%d+):(%d+)$]]

local function log_info(message)
end

local function log_error(message)
end

local function home_dir()
	return os.getenv("HOME") or wezterm.home_dir or ""
end

local function registry_dir()
	local xdg_state_home = os.getenv("XDG_STATE_HOME")
	if xdg_state_home and xdg_state_home ~= "" then
		return xdg_state_home .. "/nvim/wezterm-open-in-nvim"
	end

	return home_dir() .. "/.local/state/nvim/wezterm-open-in-nvim"
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
	if path:match("^/") then
		return normalize(path)
	end

	return normalize(base .. "/" .. path)
end

local function registry_path(pid)
	return registry_dir() .. "/" .. tostring(pid) .. ".server"
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

local function read_registry(pid)
	return read_registry_file(registry_path(pid), "pid=" .. tostring(pid))
end

local function read_all_registries()
	local registries = {}
	local entries = util.safe_read_dir(registry_dir()) or {}

	for _, entry in ipairs(entries) do
		if entry:match("%.server$") then
			local path = entry
			if not path:match("^/") then
				path = registry_dir() .. "/" .. path
			end
			local registry = read_registry_file(path, "file=" .. util.basename(path))
			if registry then
				table.insert(registries, registry)
			end
		end
	end

	log_info(("loaded %d registry file(s)"):format(#registries))
	return registries
end

local function process_pid(pane)
	local ok, info = pcall(function()
		return pane:get_foreground_process_info()
	end)
	if not ok or not info then
		log_info("pane foreground process info unavailable")
		return nil
	end

	return info.pid
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

local function consider_candidate(best, pane, tab, tab_index, registry, target_path, source_pane_id, reason, bonus)
	local pane_cwd = normalize(util.cwd_path(pane))
	local registry_score = path_score(registry.cwd, target_path)
	local pane_score = path_score(pane_cwd, target_path)
	local score = registry_score + pane_score + (bonus or 0)

	if pane:pane_id() ~= source_pane_id then
		score = score + 100000
	end

	log_info(("candidate reason=%s tab_index=%s pane_id=%s pane_cwd=%s registry_cwd=%s target=%s score=%d"):format(
		reason,
		tostring(tab_index),
		tostring(pane:pane_id()),
		pane_cwd,
		registry.cwd,
		target_path,
		score
	))

	if registry_score == 0 or pane_score == 0 then
		return best
	end

	if not best or score > best.score then
		return {
			pane = pane,
			tab = tab,
			tab_index = tab_index,
			server = registry.server,
			score = score,
		}
	end

	return best
end

local function find_nvim_pane(window, source_pane, target_path)
	local mux_window = window:mux_window()
	if not mux_window then
		return nil
	end

	local source_pane_id = source_pane:pane_id()
	local best = nil
	local registries = read_all_registries()

	for _, tab_info in ipairs(mux_window:tabs_with_info()) do
		local tab = tab_info.tab
		local tab_index = tab_info.index

		for _, item in ipairs(tab:panes_with_info()) do
			local pane = item.pane
			local pid = process_pid(pane)
			log_info(("checking tab_index=%s pane_id=%s pid=%s"):format(
				tostring(tab_index),
				tostring(pane:pane_id()),
				tostring(pid)
			))
			local registry = pid and read_registry(pid)
			if registry then
				best = consider_candidate(best, pane, tab, tab_index, registry, target_path, source_pane_id, "pid", 1000000)
			end

			for _, fallback_registry in ipairs(registries) do
				best = consider_candidate(best, pane, tab, tab_index, fallback_registry, target_path, source_pane_id, "cwd", 0)
			end
		end
	end

	return best
end

local function activate_target(window, source_pane, target)
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

local function open_in_nvim(window, pane, raw_path, raw_line, raw_column)
	local cwd = normalize(util.cwd_path(pane))
	local path = join_path(cwd, url_decode(raw_path))
	local line = tonumber(raw_line) or 1
	local column = tonumber(raw_column) or 1
	log_info(("open request raw=%s:%s:%s cwd=%s resolved=%s"):format(raw_path, raw_line, raw_column, cwd, path))

	local target = find_nvim_pane(window, pane, path)
	if not target then
		notify(window, "no matching Neovim pane in this tab")
		return false
	end

	local success, _, stderr = wezterm.run_child_process({ "nvim", "--server", target.server, "--remote", path })
	if not success then
		log_error("remote open failed: " .. tostring(stderr or ""))
		notify(window, "failed to open target: " .. tostring(stderr or ""))
		return false
	end

	success, _, stderr = wezterm.run_child_process({
		"nvim",
		"--server",
		target.server,
		"--remote-expr",
		("cursor(%d,%d)"):format(line, column),
	})
	if not success then
		log_error("remote cursor failed: " .. tostring(stderr or ""))
		notify(window, "failed to move cursor: " .. tostring(stderr or ""))
		return false
	end

	activate_target(window, pane, target)
	return true
end

local function parse_uri(uri)
	log_info("open-uri uri=" .. uri)
	local prefix = SCHEME .. ":"
	if uri:sub(1, #prefix) ~= prefix then
		log_info("ignored uri for another scheme")
		return nil
	end

	local path, line, column = uri:sub(#prefix + 1):match("^(.-):(%d+):(%d+)$")
	if not path then
		log_error("failed to parse nvim uri: " .. uri)
		return nil
	end

	log_info(("parsed uri path=%s line=%s column=%s"):format(path, line, column))
	return path, line, column
end

local function handle_open_uri(window, pane, uri)
	local path, line, column = parse_uri(uri)
	if not path then
		return nil
	end

	open_in_nvim(window, pane, path, line, column)
	return false
end

function M.apply_to_config(config)
	local rules = wezterm.default_hyperlink_rules()
	table.insert(rules, {
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
				local path, line, column = selection:match(diagnostic_lua_pattern)
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
