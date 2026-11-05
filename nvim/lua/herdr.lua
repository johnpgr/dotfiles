---@alias HerdrNavigationKey 'h'|'j'|'k'|'l'
---@alias HerdrDirection 'left'|'down'|'up'|'right'

---@class HerdrResponse
---@field error? { message?: string, code: integer }
---@field result? any

local M = {}
local uv = vim.uv or vim.loop

---@type table<HerdrNavigationKey, HerdrDirection>
local pane_direction_by_key = {
	h = "left",
	j = "down",
	k = "up",
	l = "right",
}

---@type table<HerdrNavigationKey, string>
local split_resize_command_by_key = {
	h = "vertical resize -2",
	l = "vertical resize +2",
	j = "resize -2",
	k = "resize +2",
}

---@type table<HerdrNavigationKey, HerdrNavigationKey>
local opposite_key = { h = "l", j = "k", k = "j", l = "h" }

---@type number Fraction of the pane split per resize step.
M.resize_amount = 0.02

-- Cache environment values before entering libuv's fast callbacks.
local socket_path = vim.env.HERDR_SOCKET_PATH or vim.fs.normalize("~/.config/herdr/herdr.sock")
local is_inside_herdr = vim.env.HERDR_ENV ~= nil
local has_warned = false

---@param message string
local function warn_once_inside_herdr(message)
	if has_warned or not is_inside_herdr then
		return
	end
	has_warned = true
	vim.schedule(function()
		vim.notify("herdr_nav: " .. message, vim.log.levels.WARN)
	end)
end

local request_id = 0

-- The server accepts one NDJSON request/response per connection; omit pane_id to target the focused pane.
---@param method_name string
---@param parameters table<string, any>
---@param on_response? fun(response: HerdrResponse)
function M.request(method_name, parameters, on_response)
	request_id = request_id + 1
	local encoded_request = vim.json.encode({ id = tostring(request_id), method = method_name, params = parameters })
		.. "\n"

	local pipe = uv.new_pipe(false)
	if not pipe then
		return
	end
	---@type string[]
	local response_chunks = {}
	local is_connection_closed = false

	local function close_connection_once()
		if is_connection_closed then
			return
		end
		is_connection_closed = true
		pipe:read_stop()
		pipe:close()
	end

	pipe:connect(socket_path, function(connect_error)
		if connect_error then
			close_connection_once()
			warn_once_inside_herdr("cannot reach herdr socket: " .. connect_error)
			return
		end
		pipe:write(encoded_request)
		pipe:read_start(function(read_error, chunk)
			if read_error then
				close_connection_once()
				warn_once_inside_herdr("socket read failed: " .. read_error)
				return
			end
			if chunk then
				response_chunks[#response_chunks + 1] = chunk
				if not chunk:find("\n", 1, true) then
					return
				end
			end
			close_connection_once()
			local decoded, response = pcall(vim.json.decode, table.concat(response_chunks))
			if not decoded or type(response) ~= "table" then
				return
			end
			if response.error then
				warn_once_inside_herdr(("%s: %s"):format(method_name, response.error.message or response.error.code))
			end
			if on_response then
				vim.schedule(function()
					on_response(response)
				end)
			end
		end)
	end)
end

---@param navigation_key HerdrNavigationKey
---@return boolean
local function has_split_neighbor_on_axis(navigation_key)
	local current_window = vim.fn.winnr()
	return vim.fn.winnr(navigation_key) ~= current_window
		or vim.fn.winnr(opposite_key[navigation_key]) ~= current_window
end

---@param navigation_key HerdrNavigationKey
function M.navigate(navigation_key)
	local previous_window = vim.fn.winnr()
	vim.cmd("wincmd " .. navigation_key)
	if vim.fn.winnr() == previous_window then
		M.request("pane.focus_direction", { direction = pane_direction_by_key[navigation_key] })
	end
end

---@param navigation_key HerdrNavigationKey
function M.resize(navigation_key)
	if has_split_neighbor_on_axis(navigation_key) then
		vim.cmd(split_resize_command_by_key[navigation_key])
	else
		M.request("pane.resize", { direction = pane_direction_by_key[navigation_key], amount = M.resize_amount })
	end
end

return M
