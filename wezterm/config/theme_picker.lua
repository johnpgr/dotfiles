local wezterm = require("wezterm")
local prompt = require("config.prompt")
local theme = require("config.theme")

local act = wezterm.action
local M = {}

local native_picker
local color_names = {
	"black",
	"red",
	"green",
	"yellow",
	"blue",
	"magenta",
	"cyan",
	"white",
}

local function scheme_sort(a, b)
	return a:lower() < b:lower()
end

local function color_scheme_names(schemes)
	schemes = schemes or wezterm.color.get_builtin_schemes()
	local names = {}

	for name, _ in pairs(schemes) do
		table.insert(names, name)
	end

	table.sort(names, scheme_sort)
	return names
end

local function hex_rgb(color)
	local text = tostring(color or ""):lower()
	local r, g, b = text:match("#?(%x%x)(%x%x)(%x%x)")
	if not r then
		return nil
	end

	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function fg(color)
	local r, g, b = hex_rgb(color)
	if not r then
		return ""
	end

	return ("\27[38;2;%d;%d;%dm"):format(r, g, b)
end

local function bg(color)
	local r, g, b = hex_rgb(color)
	if not r then
		return ""
	end

	return ("\27[48;2;%d;%d;%dm"):format(r, g, b)
end

local function text_on(foreground, background, text)
	return bg(background) .. fg(foreground) .. text
end

local function padded(text, width)
	local pad = width - #text
	if pad < 0 then
		pad = 0
	end

	return text .. string.rep(" ", pad)
end

local function preview_line(palette, background)
	local parts = {}
	for index, name in ipairs(color_names) do
		table.insert(parts, fg(palette[index]) .. name)
	end

	return bg(background) .. table.concat(parts, " ")
end

local function preview_swatches(palette, foreground)
	local lines = {}
	for index, name in ipairs(color_names) do
		local color = palette[index]
		table.insert(lines, bg(color) .. fg(foreground) .. padded(" " .. name .. " ", 16))
	end

	return lines
end

local function fill_line(background, line)
	return bg(background) .. (line or "") .. bg(background) .. "\27[K\27[0m"
end

local function add_line(lines, background, line)
	table.insert(lines, fill_line(background, line))
end

local function add_lines(lines, background, new_lines)
	for _, line in ipairs(new_lines) do
		add_line(lines, background, line)
	end
end

local function scheme_preview(schemes, name)
	local colors = schemes[name] or {}
	local foreground = colors.foreground or "#d0d0d0"
	local background = colors.background or "#000000"
	local selection_fg = colors.selection_fg or background
	local selection_bg = colors.selection_bg or foreground
	local ansi = colors.ansi or {}
	local brights = colors.brights or ansi
	local lines = {}

	add_line(lines, background, text_on(foreground, background, " " .. name .. " "))
	add_line(lines, background, "")
	add_line(lines, background, fg(foreground) .. bg(background) .. "The quick brown fox jumps over the lazy dog 0123456789")
	add_line(lines, background, text_on(selection_fg, selection_bg, " selected text sample "))
	add_line(lines, background, "")
	add_line(lines, background, preview_line(ansi, background))
	add_line(lines, background, preview_line(brights, background))
	add_line(lines, background, "")
	add_line(lines, background, preview_line(ansi, ansi[1] or background))
	add_line(lines, background, preview_line(brights, ansi[1] or background))
	add_line(lines, background, "")
	add_line(lines, background, preview_line(ansi, brights[8] or foreground))
	add_line(lines, background, preview_line(brights, brights[8] or foreground))
	add_line(lines, background, "")
	add_line(lines, background, preview_line(ansi, ansi[4] or background))
	add_line(lines, background, preview_line(brights, ansi[4] or background))
	add_line(lines, background, "")
	add_lines(lines, background, preview_swatches(ansi, foreground))
	add_lines(lines, background, preview_swatches(brights, foreground))
	add_line(lines, background, "")
	add_line(
		lines,
		background,
		fg(ansi[2]) .. "error"
			.. fg(foreground) .. "  "
			.. fg(ansi[3]) .. "success"
			.. fg(foreground) .. "  "
			.. fg(ansi[4]) .. "warning"
			.. fg(foreground) .. "  "
			.. fg(ansi[5]) .. "info"
			.. fg(foreground) .. "  "
			.. fg(ansi[6]) .. "accent"
	)

	while #lines < 80 do
		add_line(lines, background, "")
	end

	return table.concat(lines, "\n")
end

local function slot_file(slot)
	if slot == "light" then
		return theme.light_color_scheme_file
	end

	return theme.dark_color_scheme_file
end

local function shell_quote(value)
	return wezterm.shell_quote_arg(value)
end

local function make_work_dir()
	local path = os.tmpname()
	os.remove(path)

	local success, _, stderr = wezterm.run_child_process({ "mkdir", "-p", path .. "/previews" })
	if not success then
		return nil, stderr
	end

	return path
end

local function write_scheme_files(work_dir)
	local schemes = wezterm.color.get_builtin_schemes()
	local choices_path = work_dir .. "/choices.tsv"
	local preview_dir = work_dir .. "/previews"
	local file, err = io.open(choices_path, "w")
	if not file then
		return false, err
	end

	for index, name in ipairs(color_scheme_names(schemes)) do
		local id = ("%04d"):format(index)
		file:write(id, "\t", name, "\n")

		local preview_file, preview_err = io.open(preview_dir .. "/" .. id .. ".ansi", "w")
		if not preview_file then
			file:close()
			return false, preview_err
		end

		preview_file:write(scheme_preview(schemes, name))
		preview_file:close()
	end

	file:close()
	return true, choices_path, preview_dir
end

local function fzf_available()
	local success = wezterm.run_child_process({ "bash", "-lc", "command -v fzf" })
	return success
end

local function fzf_command(slot)
	local work_dir, err = make_work_dir()
	if not work_dir then
		return nil, err
	end

	local ok, choices_file, preview_dir = write_scheme_files(work_dir)
	if not ok then
		return nil, choices_file
	end

	local prompt_text = slot == "light" and "Light scheme: " or "Dark scheme: "
	local target_file = slot_file(slot)
	local preview_command = table.concat({
		"line=\"$1\"",
		"id=$(printf '%s\\n' \"$line\" | cut -f1)",
		"cat \"$2/$id.ansi\"",
	}, "; ")
	local preview_action = "bash -lc " .. shell_quote(preview_command) .. " -- {} " .. shell_quote(preview_dir)

	return table.concat({
		"choices=" .. shell_quote(choices_file),
		"preview_dir=" .. shell_quote(preview_dir),
		"work_dir=" .. shell_quote(work_dir),
		"target_file=" .. shell_quote(target_file),
		"selection=$(fzf --ansi --delimiter='	' --with-nth=2.. --prompt="
			.. shell_quote(prompt_text)
			.. " --height=100% --layout=reverse --border=none --preview-window=right:70%:wrap --preview="
			.. shell_quote(preview_action)
			.. " < \"$choices\")",
		"status=$?",
		"rm -rf \"$work_dir\"",
		"if [ \"$status\" -eq 0 ] && [ -n \"$selection\" ]; then",
		"  scheme=$(printf '%s\\n' \"$selection\" | cut -f2-)",
		"  printf '%s\\n' \"$scheme\" > \"$target_file\"",
		"  printf 'Saved %s\\n' \"$scheme\"",
		"fi",
	}, "\n")
end

local function open_fzf_picker(window, pane, slot)
	local command, err = fzf_command(slot)
	if not command then
		window:toast_notification("wezterm theme", "falling back to native picker: " .. tostring(err), nil, 4000)
		local is_light = slot == "light"
		local current = is_light and theme.read_light_color_scheme() or theme.read_dark_color_scheme()
		native_picker(window, pane, slot, current)
		return
	end

	window:perform_action(
		act.SpawnCommandInNewTab({
			args = { "bash", "-lc", command },
		}),
		pane
	)
end

native_picker = function(window, pane, slot, current)
	local is_light = slot == "light"
	local title = is_light and "Choose light colorscheme" or "Choose dark colorscheme"

	window:perform_action(
		prompt
			.select(title)
			:search("Scheme: ")
			:choices(color_scheme_names)
			:current(function()
				return current
			end)
			:save_to(slot_file(slot))
			:reload()
			:notify_as("wezterm theme")
			:action(),
		pane
	)
end

local function edit_slot(window, pane, slot)
	local is_light = slot == "light"
	local current = is_light and theme.read_light_color_scheme() or theme.read_dark_color_scheme()

	if fzf_available() then
		open_fzf_picker(window, pane, slot)
	else
		native_picker(window, pane, slot, current)
	end
end

function M.apply_to_config() end

function M.action()
	return prompt
		.select("Choose theme slot")
		:search("Slot: ")
		:choices({
			{ id = "dark", label = "Dark - " .. theme.read_dark_color_scheme() },
			{ id = "light", label = "Light - " .. theme.read_light_color_scheme() },
		})
		:current(theme.read_theme_mode)
		:on_select(edit_slot)
		:notify_as("wezterm theme")
		:action()
end

return M
