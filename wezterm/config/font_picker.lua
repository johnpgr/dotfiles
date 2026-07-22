local wezterm = require("wezterm")
local prompt = require("config.prompt")
local theme = require("config.theme")

local M = {}

local font_cache_file = theme.font_family_file .. "_families"
local font_cache_version = "wezterm-font-families-v1"

local fallback_families = {
	theme.default_font_family,
	"JetBrains Mono",
	"Consolas",
	"Cascadia Mono",
	"Cascadia Code",
	"Courier New",
}

local function trim(text)
	return text and text:match("^%s*(.-)%s*$") or ""
end

local function is_useful_family(family)
	return family ~= ""
		and not family:match("[Ee]moji")
		and not family:match("^Cursor$")
		and not family:match("^Symbols")
end

local function add_family(families, seen, family)
	family = trim(family)
	if not is_useful_family(family) or seen[family] then
		return
	end

	seen[family] = true
	table.insert(families, family)
end

local function family_sort(a, b)
	return a:lower() < b:lower()
end

local function parse_fc_list(output)
	local families = {}
	local seen = {}

	for _, family in ipairs(fallback_families) do
		add_family(families, seen, family)
	end

	for line in output:gmatch("[^\r\n]+") do
		local family = line:match("^([^,]+)")
		add_family(families, seen, family)
	end

	table.sort(families, family_sort)
	return families
end

local function parse_wezterm_ls_fonts(output)
	local families = {}
	local seen = {}

	for _, family in ipairs(fallback_families) do
		add_family(families, seen, family)
	end

	for family in output:gmatch('wezterm%.font%("([^"]+)"') do
		if family:match("[Mm]ono") or family:match("[Cc]ode") or family:match("[Tt]erm") then
			add_family(families, seen, family)
		end
	end

	for family in output:gmatch('family="([^"]+)"') do
		if family:match("[Mm]ono") or family:match("[Cc]ode") or family:match("[Tt]erm") then
			add_family(families, seen, family)
		end
	end

	table.sort(families, family_sort)
	return families
end

local function run_child_process(args)
	local ok, success, stdout, stderr = pcall(wezterm.run_child_process, args)
	if ok then
		return success, stdout, stderr
	end

	wezterm.log_warn("unable to run font picker command: " .. tostring(success))
	return false, "", tostring(success)
end

local function wezterm_executable()
	local executable_name = wezterm.target_triple:find("windows") and "wezterm.exe" or "wezterm"
	return wezterm.executable_dir:gsub("\\", "/"):gsub("/+$", "") .. "/" .. executable_name
end

local function font_cache_signature()
	local is_macos = wezterm.target_triple:find("darwin") ~= nil
	local refresh_period = is_macos and os.date("%Y-%W") or os.date("%Y-%m-%d")
	local parts = { wezterm.target_triple, refresh_period }

	if is_macos then
		local paths = {
			wezterm.home_dir .. "/Library/Fonts",
			"/Library/Fonts",
			"/System/Library/Fonts",
			wezterm_executable(),
		}

		for _, path in ipairs(paths) do
			local success, stdout = run_child_process({ "stat", "-f", "%m", path })
			table.insert(parts, success and trim(stdout) or "missing")
		end
	end

	return table.concat(parts, "|")
end

local function read_font_cache(signature)
	local file = io.open(font_cache_file, "r")
	if not file then
		return nil
	end

	local version = trim(file:read("*line"))
	local cached_signature = trim(file:read("*line"))
	if version ~= font_cache_version or cached_signature ~= signature then
		file:close()
		return nil
	end

	local families = {}
	local seen = {}
	for family in file:lines() do
		add_family(families, seen, family)
	end
	file:close()

	if #families == 0 then
		return nil
	end

	table.sort(families, family_sort)
	return families
end

local function write_font_cache(signature, families)
	local file, err = io.open(font_cache_file, "w")
	if not file then
		wezterm.log_warn("unable to write font picker cache: " .. tostring(err))
		return
	end

	file:write(font_cache_version, "\n", signature, "\n")
	for _, family in ipairs(families) do
		file:write(family, "\n")
	end
	file:close()
end

local function discover_font_families()
	local success, stdout = run_child_process({ "fc-list", ":spacing=100", "family" })
	if success and stdout and stdout ~= "" then
		return parse_fc_list(stdout), true
	end

	success, stdout = run_child_process({ wezterm_executable(), "ls-fonts", "--list-system" })
	if success and stdout and stdout ~= "" then
		return parse_wezterm_ls_fonts(stdout), true
	end

	return parse_fc_list(""), false
end

local function list_font_families()
	local signature = font_cache_signature()
	local cached_families = read_font_cache(signature)
	if cached_families then
		return cached_families
	end

	local families, discovered = discover_font_families()
	if discovered then
		write_font_cache(signature, families)
	end

	return families
end

function M.action()
	return prompt
		.select("Choose monospace font")
		:search("Font: ")
		:choices(list_font_families)
		:current(theme.read_font_family)
		:save_to(theme.font_family_file)
		:reload()
		:notify_as("wezterm font")
		:action()
end

return M
