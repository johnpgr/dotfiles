local M = {}

local state_dir = vim.fs.joinpath(vim.env.HOME, ".dotfiles")
local state_file = vim.fs.joinpath(state_dir, ".theme_state")

local function read_mode()
	local f = io.open(state_file, "r")
	if not f then
		return nil
	end
	local mode = vim.trim(f:read("*a") or "")
	f:close()
	return (mode == "dark" or mode == "light") and mode or nil
end

local function apply(mode)
	if mode and vim.o.background ~= mode then
		vim.o.background = mode
	end
end

function M.setup()
	apply(read_mode())

	local stat = vim.uv.fs_stat(state_dir)
	if not stat or stat.type ~= "directory" then
		return
	end

	local debounce_timer = vim.uv.new_timer()
	if not debounce_timer then
		return
	end

	local function schedule_apply()
		debounce_timer:stop()
		debounce_timer:start(100, 0, function()
			vim.schedule(function()
				apply(read_mode())
			end)
		end)
	end

	local fs_event = vim.uv.new_fs_event()
	if not fs_event then
		debounce_timer:close()
		return
	end

	local ok = fs_event:start(state_dir, {}, function(err, filename)
		if err then
			return
		end
		if filename ~= ".theme_state" then
			return
		end
		schedule_apply()
	end)

	if not ok then
		fs_event:close()
		debounce_timer:close()
		return
	end

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			fs_event:stop()
			fs_event:close()
			debounce_timer:stop()
			debounce_timer:close()
		end,
	})
end

return M
