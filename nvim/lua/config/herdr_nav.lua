-- Split navigation/resizing that falls through to herdr panes at the edge
-- of the nvim window layout, mirroring what tmux.nvim did for tmux panes.
--
-- herdr is driven over its unix socket directly via libuv (NDJSON), so the hot
-- path never spawns a process. The herdr server is the daemon; nvim just talks
-- to it.
--
-- Why a fresh connection per request rather than one held open: the server
-- enforces one request/response per connection and closes it after replying.
-- The only long-lived connections it allows are `events.subscribe` streams,
-- and sending a regular request on one of those resets the connection
-- (verified against herdr 0.8.x). The connect itself is ~20µs of a ~250µs
-- round trip; the rest is server-side, so a persistent pipe would not help
-- even if it were possible.
local M = {}

local uv = vim.uv or vim.loop

local herdr_dir = {
	h = "left",
	j = "down",
	k = "up",
	l = "right",
}

local resize_cmd = {
	h = "vertical resize -2",
	l = "vertical resize +2",
	j = "resize -2",
	k = "resize +2",
}

-- Split ratio delta per resize step (0.02 ≈ 2% of the split).
M.resize_amount = 0.02

-- Read the environment once, on the main thread: the libuv callbacks below run
-- in a fast event context where vim.env / vim.fn are not allowed.
local socket_path = vim.env.HERDR_SOCKET_PATH or vim.fs.normalize("~/.config/herdr/herdr.sock")
local inside_herdr = vim.env.HERDR_ENV ~= nil

local warned = false
local function warn_once(msg)
	-- Only complain when we are actually inside herdr; outside it, falling
	-- through to a no-op at the layout edge is the expected behaviour.
	if warned or not inside_herdr then
		return
	end
	warned = true
	vim.schedule(function()
		vim.notify("herdr_nav: " .. msg, vim.log.levels.WARN)
	end)
end

local next_id = 0

---Send one request to the herdr server. `pane_id` is deliberately omitted so
---the server acts on the focused pane -- the one receiving this keypress.
---@param method string
---@param params table
---@param on_reply? fun(reply: table)
function M.request(method, params, on_reply)
	next_id = next_id + 1
	local body = vim.json.encode({ id = tostring(next_id), method = method, params = params }) .. "\n"

	local pipe = uv.new_pipe(false)
	if not pipe then
		return
	end
	local buf = {}
	local closed = false
	local function finish()
		if closed then
			return
		end
		closed = true
		pipe:read_stop()
		pipe:close()
	end

	pipe:connect(socket_path, function(err)
		if err then
			finish()
			warn_once("cannot reach herdr socket: " .. err)
			return
		end
		pipe:write(body)
		pipe:read_start(function(rerr, chunk)
			if rerr then
				finish()
				warn_once("socket read failed: " .. rerr)
				return
			end
			if chunk then
				buf[#buf + 1] = chunk
				if not chunk:find("\n", 1, true) then
					return
				end
			end
			finish()
			local ok, reply = pcall(vim.json.decode, table.concat(buf))
			if not ok or type(reply) ~= "table" then
				return
			end
			if reply.error then
				warn_once(("%s: %s"):format(method, reply.error.message or reply.error.code))
			end
			if on_reply then
				vim.schedule(function()
					on_reply(reply)
				end)
			end
		end)
	end)
end

---Move focus in `key`'s direction (h/j/k/l); at the edge of nvim's window
---layout, forward focus to the neighboring herdr pane instead.
---@param key "h"|"j"|"k"|"l"
function M.navigate(key)
	local before = vim.fn.winnr()
	vim.cmd("wincmd " .. key)
	if vim.fn.winnr() == before then
		M.request("pane.focus_direction", { direction = herdr_dir[key] })
	end
end

---Resize the current split toward `key`'s direction; at the edge of nvim's
---window layout, resize the herdr pane instead.
---@param key "h"|"j"|"k"|"l"
function M.resize(key)
	if vim.fn.winnr(key) == vim.fn.winnr() then
		M.request("pane.resize", { direction = herdr_dir[key], amount = M.resize_amount })
	else
		vim.cmd(resize_cmd[key])
	end
end

return M
