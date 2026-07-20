-- Reusable lazy-load helpers on top of vim.pack. vim.pack.add() has no
-- built-in event/keys/command lazy-loading (opts.load=false only skips
-- sourcing plugin/ and ftdetect/ files); these wrap that primitive so
-- plugin/*.lua files can defer vim.pack.add() + setup() to the point of
-- actual use.
local M = {}

---@param specs (string|vim.pack.Spec)[]
local function packadd_all(specs)
	vim.pack.add(specs, { load = false })
	for _, spec in ipairs(specs) do
		local name = type(spec) == "table" and spec.name
		if not name then
			local src = type(spec) == "table" and spec.src or spec
			name = src:match("([^/]+)$"):gsub("%.git$", "")
		end
		pcall(vim.cmd.packadd, name)
	end
end

--- Build an idempotent loader: the first call runs vim.pack.add(specs) +
--- packadd + setup(); every later call is a no-op. Share one loader across
--- on_event/on_keys/on_command for the same plugin so it's only loaded once
--- no matter which trigger fires first.
---@param specs (string|vim.pack.Spec)[]
---@param setup fun()
---@return fun()
function M.loader(specs, setup)
	local loaded = false
	return function()
		if loaded then
			return
		end
		loaded = true
		packadd_all(specs)
		setup()
	end
end

--- Call `load()` once when any of `events` fires.
---@param events string|string[]
---@param load fun()
---@param autocmd_opts? vim.api.keyset.create_autocmd
function M.on_event(events, load, autocmd_opts)
	local opts = vim.tbl_extend("force", autocmd_opts or {}, {
		once = true,
		callback = load,
	})
	vim.api.nvim_create_autocmd(events, opts)
end

--- Wrap keymaps so the first press of any of them calls `load()` then that
--- key's real `fn`, so keymaps that invoke plugin-defined commands work
--- correctly on the very first press.
---@param load fun()
---@param keys { mode: string|string[], lhs: string, fn: fun(), desc?: string }[]
function M.on_keys(load, keys)
	for _, key in ipairs(keys) do
		vim.keymap.set(key.mode, key.lhs, function()
			load()
			key.fn()
		end, { desc = key.desc })
	end
end

--- Register placeholder user commands for `commands` so typing e.g. `:Neogit`
--- directly (without ever pressing a lazy-loading keymap) still works. The
--- first invocation of any of them deletes *all* the placeholders (so the
--- plugin's own `nvim_create_user_command` calls don't collide with ours),
--- calls `load()`, then re-dispatches the original command with its
--- args/bang.
---
--- Returns a wrapped loader that also does this placeholder cleanup -- pass
--- it to on_event/on_keys instead of the original `load` for the same
--- plugin, so a keymap firing first also cleans up the placeholders before
--- the plugin defines its real commands.
---@param load fun()
---@param commands string|string[]
---@return fun()
function M.on_command(load, commands)
	commands = type(commands) == "string" and { commands } or commands

	local cleaned = false
	local function wrapped_load()
		if not cleaned then
			cleaned = true
			for _, name in ipairs(commands) do
				pcall(vim.api.nvim_del_user_command, name)
			end
		end
		load()
	end

	for _, name in ipairs(commands) do
		vim.api.nvim_create_user_command(name, function(opts)
			wrapped_load()
			local cmd = name
			if opts.bang then
				cmd = cmd .. "!"
			end
			if opts.args ~= "" then
				cmd = cmd .. " " .. opts.args
			end
			vim.cmd(cmd)
		end, { nargs = "*", bang = true, desc = "lazy_pack: load then run :" .. name })
	end

	return wrapped_load
end

return M
