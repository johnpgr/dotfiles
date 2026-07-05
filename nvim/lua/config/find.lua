local uv = vim.uv or vim.loop

local fff_state = {
	initialized = false,
	base_path = nil,
	fuzzy = nil,
}

local function is_home_dir(path)
	local home = uv.os_homedir()
	if not path or not home then
		return false
	end

	local real_path = uv.fs_realpath(path) or vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
	local real_home = uv.fs_realpath(home) or vim.fn.fnamemodify(home, ":p"):gsub("/+$", "")
	return real_path == real_home
end

local function ensure_fff(base_path)
	if fff_state.initialized then
		return fff_state.fuzzy
	end

	local plug_dir = vim.fn.stdpath("data") .. "/site/pack/core/opt"
	if vim.uv.fs_stat(plug_dir .. "/fff.nvim") then
		vim.o.rtp = plug_dir .. "/fff.nvim," .. vim.o.rtp
	end

	local cwd = vim.fn.getcwd()
	local target_path = base_path or cwd
	if is_home_dir(target_path) then
		return nil
	end

	vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, { base_path = target_path, lazy_sync = true })

	local ok, fuzzy = pcall(require, "fff.fuzzy")
	if not ok then
		return nil
	end

	local core_ok, core = pcall(require, "fff.core")
	if core_ok and type(core.ensure_initialized) == "function" then
		local init_ok = pcall(core.ensure_initialized)
		if not init_ok then
			return nil
		end
	else
		return nil
	end

	fff_state.fuzzy = fuzzy
	fff_state.base_path = target_path
	fff_state.initialized = true

	local group = vim.api.nvim_create_augroup("fff_pick", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			local f = ev.file
			if f and f ~= "" and not vim.startswith(f, "term://") then
				pcall(fuzzy.track_access, uv.fs_realpath(f) or f)
			end
		end,
	})

	vim.api.nvim_create_autocmd("DirChanged", {
		group = group,
		callback = function()
			local cwd = vim.fn.getcwd()
			if is_home_dir(cwd) then
				return
			end

			if cwd ~= fff_state.base_path then
				pcall(fuzzy.restart_index_in_path, cwd)
				fff_state.base_path = cwd
			end
		end,
	})

	return fuzzy
end

-- fff-backed :find completion
function _G.dotfiles_find_func(arg_lead, cmdline, cursorpos)
	local fuzzy = ensure_fff()
	if not fuzzy then
		return {}
	end

	if arg_lead == "" then
		local ok, result = pcall(fuzzy.fuzzy_search_files, "", 4, nil, 100, nil, 0, 100)
		if not ok or not result or not result.items then
			return {}
		end

		local paths = {}
		for _, item in ipairs(result.items) do
			if item.relative_path then
				table.insert(paths, item.relative_path)
			end
		end
		return paths
	end

	local ok, result = pcall(fuzzy.fuzzy_search_files, arg_lead, 4, nil, 100, nil, 0, 100)
	if not ok or not result or not result.items then
		return {}
	end

	local paths = {}
	for _, item in ipairs(result.items) do
		if item.relative_path then
			table.insert(paths, item.relative_path)
		end
	end
	return paths
end

vim.o.findfunc = "v:lua.dotfiles_find_func"

vim.keymap.set("n", "<leader><space>", function()
	ensure_fff()
	vim.api.nvim_feedkeys(":find ", "n", false)
end, { desc = "Find file" })

-- <C-q> on :find: send wildmenu matches to quickfix
vim.keymap.set("c", "<C-q>", function()
	local function passthrough()
		vim.api.nvim_feedkeys(
			vim.api.nvim_replace_termcodes("<C-v>", true, false, true),
			"n",
			true
		)
	end

	if vim.fn.getcmdtype() ~= ":" then
		return passthrough()
	end

	local cmdline = vim.fn.getcmdline()
	if not cmdline:match("^%s*fin") then
		return passthrough()
	end

	local info = vim.fn.cmdcomplete_info()
	if not info.matches or #info.matches == 0 then
		return passthrough()
	end

	local qf_items = {}
	for _, match in ipairs(info.matches) do
		local filepath = vim.fn.fnamemodify(match, ":p")
		if vim.fn.filereadable(filepath) == 1 then
			table.insert(qf_items, { filename = filepath, lnum = 1, col = 1 })
		end
	end

	if #qf_items == 0 then
		return passthrough()
	end

	vim.fn.setqflist({}, " ", {
		items = qf_items,
		title = vim.trim(cmdline),
		nr = "$",
	})
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<C-c>", true, false, true),
		"n",
		true
	)
	vim.schedule(function()
		vim.cmd("copen")
	end)
end)

return {
	ensure_fff = ensure_fff,
	open = function()
		ensure_fff()
		vim.api.nvim_feedkeys(":find ", "n", false)
	end,
}
