local wezterm = require("wezterm")
local prompt = require("config.prompt")
local theme = require("config.theme")

local M = {}

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
	local exe = wezterm.executable_dir:gsub("\\", "/"):gsub("/+$", "") .. "/wezterm.exe"
	return exe
end

local function list_font_families()
	local success, stdout = run_child_process({ "fc-list", ":spacing=100", "family" })
	if success and stdout and stdout ~= "" then
		return parse_fc_list(stdout)
	end

	success, stdout = run_child_process({ wezterm_executable(), "ls-fonts", "--list-system" })
	if success and stdout and stdout ~= "" then
		return parse_wezterm_ls_fonts(stdout)
	end

	return parse_fc_list("")
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
