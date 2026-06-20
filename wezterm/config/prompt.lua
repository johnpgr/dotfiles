local wezterm = require("wezterm")

local act = wezterm.action
local M = {}

local Prompt = {}
Prompt.__index = Prompt

local function trim(text)
	return text and text:match("^%s*(.-)%s*$") or ""
end

local function value_of(value, ...)
	if type(value) == "function" then
		return value(...)
	end

	return value
end

local function notify(window, title, message)
	window:toast_notification(title, message, nil, 4000)
end

local function write_file(path, value)
	local file, err = io.open(path, "w")
	if not file then
		return false, err
	end

	file:write(value, "\n")
	file:close()
	return true
end

local function normalize_option(option)
	if type(option) == "table" then
		local id = option.id or option.value
		return {
			id = id,
			label = option.label or tostring(id),
		}
	end

	return {
		id = option,
		label = tostring(option),
	}
end

local function selector_choices(options, current)
	local choices = {}

	for _, option in ipairs(options or {}) do
		local choice = normalize_option(option)
		if choice.id == current then
			choice.label = choice.label .. "  (current)"
		end
		table.insert(choices, choice)
	end

	return choices
end

function M.select(title)
	return setmetatable({
		title_text = title,
		fuzzy_enabled = true,
	}, Prompt)
end

function M.read_file(path, fallback)
	local file, err = io.open(path, "r")
	if not file then
		if err and not err:match("No such file") then
			wezterm.log_warn("unable to read prompt state: " .. err)
		end
		return fallback
	end

	local value = trim(file:read("*all"))
	file:close()

	if value == "" then
		return fallback
	end

	return value
end

function Prompt:search(description)
	self.fuzzy_description = description
	return self
end

function Prompt:choices(options)
	self.options = options
	return self
end

function Prompt:current(value)
	self.current_value = value
	return self
end

function Prompt:save(save)
	self.save_selected = save
	return self
end

function Prompt:save_to(path)
	self.save_path = path
	return self
end

function Prompt:on_select(select)
	self.select_selected = select
	return self
end

function Prompt:reload()
	self.reload_after_save = true
	return self
end

function Prompt:notify_as(title)
	self.notification_title = title
	return self
end

function Prompt:action()
	return wezterm.action_callback(function(window, pane)
		local current = value_of(self.current_value)
		local choices = selector_choices(value_of(self.options) or {}, current)

		window:perform_action(
			act.InputSelector({
				title = self.title_text,
				choices = choices,
				fuzzy = self.fuzzy_enabled,
				fuzzy_description = self.fuzzy_description,
				action = wezterm.action_callback(function(inner_window, inner_pane, value)
					if not value then
						return
					end

					if self.select_selected then
						self.select_selected(inner_window, inner_pane, value)
						return
					end

					local ok, err = true, nil
					if self.save_selected then
						ok, err = self.save_selected(value)
					elseif self.save_path then
						ok, err = write_file(self.save_path, value)
					end

					if not ok then
						notify(inner_window, self.notification_title or "wezterm", "failed to save selection: " .. tostring(err))
						return
					end

					if self.reload_after_save then
						inner_window:perform_action(act.ReloadConfiguration, inner_pane)
					end
				end),
			}),
			pane
		)
	end)
end

return M
