-- Mini.pick + fff (fast file finder) pickers, and all picker-related keymaps

local uv = vim.uv or vim.loop
local fff_state = {
	initialized = false,
	base_path = nil,
	fuzzy = nil,
}

-- --------------------------------------------------------------------------
-- fff backend
-- --------------------------------------------------------------------------

local function ensure_fff()
	if fff_state.initialized then
		return fff_state.fuzzy
	end

	pcall(vim.cmd.packadd, "fff.nvim")

	local ok, fuzzy = pcall(require, "fff.fuzzy")
	if not ok then
		return nil
	end

	local core_ok, core = pcall(require, "fff.core")
	if core_ok and type(core.ensure_initialized) == "function" then
		pcall(core.ensure_initialized)
	else
		pcall(fuzzy.init_db)
		pcall(fuzzy.scan_files)
	end

	fff_state.fuzzy = fuzzy
	fff_state.base_path = vim.fn.getcwd()
	fff_state.initialized = true

	local group = vim.api.nvim_create_augroup("fff_pick", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			local f = ev.file
			if f and f ~= "" and not vim.startswith(f, "term://") then
				pcall(fuzzy.track_access, vim.uv.fs_realpath(f) or f)
			end
		end,
	})

	vim.api.nvim_create_autocmd("DirChanged", {
		group = group,
		callback = function()
			local cwd = vim.fn.getcwd()
			if cwd ~= fff_state.base_path then
				pcall(fuzzy.restart_index_in_path, cwd)
				fff_state.base_path = cwd
			end
		end,
	})

	return fuzzy
end

-- --------------------------------------------------------------------------
-- Mini.pick helpers
-- --------------------------------------------------------------------------

local function mini_pick()
	return require("mini.pick")
end

local function split_query_text(text)
	if not text or text == "" then
		return {}
	end

	return vim.fn.split(text, "\\zs")
end

local function set_picker_default_text(text)
	if not text or text == "" then
		return nil
	end

	local MiniPick = mini_pick()
	local group = vim.api.nvim_create_augroup("MiniPickDefaultQuery" .. tostring(uv.hrtime()), { clear = true })

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "MiniPickStart",
		once = true,
		callback = function()
			vim.schedule(function()
				if MiniPick.get_picker_opts() == nil then
					return
				end

				MiniPick.set_picker_query(split_query_text(text))
			end)
		end,
	})

	return group
end

local function picker_prompt(label)
	if not label or label == "" then
		return " "
	end

	return label .. " "
end

local function picker_window(label, window)
	return vim.tbl_deep_extend("force", {
		prompt_prefix = picker_prompt(label),
	}, window or {})
end

local function picker_item_to_qf(item)
	if type(item) ~= "table" then
		return nil
	end

	local qf_item = {
		lnum = item.lnum or 1,
		col = item.col or 1,
		text = item.text or item.path or item.filename or "",
	}
	if item.bufnr then
		qf_item.bufnr = item.bufnr
	elseif item.path then
		qf_item.filename = item.path
	elseif item.filename then
		qf_item.filename = item.filename
	else
		return nil
	end

	return qf_item
end

local function add_picker_matches_to_qflist()
	local matches = mini_pick().get_picker_matches()
	local items = matches and matches.all or {}
	local qf_items = {}

	for _, item in ipairs(items) do
		local qf_item = picker_item_to_qf(item)
		if qf_item then
			table.insert(qf_items, qf_item)
		end
	end

	vim.fn.setqflist(qf_items, "r")
	if #qf_items > 0 then
		vim.schedule(function()
			vim.cmd("copen")
		end)
	end
	return true
end

local function picker_mappings(mappings)
	return vim.tbl_deep_extend("force", mappings or {}, {
		qflist = {
			char = vim.api.nvim_replace_termcodes("<C-q>", true, true, true),
			func = add_picker_matches_to_qflist,
		},
	})
end

local function pick_start(opts)
	local default_query_group = set_picker_default_text(opts.default_text)
	local choice = mini_pick().start({
		source = {
			items = opts.items,
			name = opts.name or opts.prompt or "Pick",
			cwd = opts.cwd,
			show = opts.show,
			preview = opts.preview,
			choose = opts.choose,
			choose_marked = opts.choose_marked,
		},
		mappings = picker_mappings(opts.mappings),
		options = opts.options,
		window = picker_window(opts.prompt, opts.window),
	})

	if default_query_group then
		pcall(vim.api.nvim_del_augroup_by_id, default_query_group)
	end

	return choice
end

local function pick_dynamic(opts)
	local MiniPick = mini_pick()
	local group = vim.api.nvim_create_augroup("MiniPickDynamic" .. tostring(uv.hrtime()), { clear = true })
	local last_query = nil

	local function refresh_items()
		if MiniPick.get_picker_opts() == nil then
			return
		end

		local query = table.concat(MiniPick.get_picker_query() or {})
		if query == last_query then
			return
		end
		last_query = query

		local querytick = MiniPick.get_querytick()
		local ok, items = pcall(opts.items, query)
		if not ok then
			vim.notify(items, vim.log.levels.ERROR)
			items = {}
		end

		MiniPick.set_picker_items(items or {}, { querytick = querytick, do_match = false })
	end

	opts.refresh = function()
		last_query = nil
		refresh_items()
	end

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "MiniPickStart", "MiniPickMatch", "MiniPickStop" },
		callback = function(ev)
			if ev.match == "MiniPickStop" then
				if opts.on_close then
					opts.on_close()
				end
				pcall(vim.api.nvim_del_augroup_by_id, group)
				return
			end

			refresh_items()
		end,
	})

	local result = pick_start({
		items = nil,
		name = opts.name,
		prompt = opts.prompt,
		cwd = opts.cwd,
		show = opts.show,
		preview = opts.preview,
		choose = opts.choose,
		choose_marked = opts.choose_marked,
		mappings = opts.mappings,
		options = vim.tbl_deep_extend("force", { use_cache = false }, opts.options or {}),
		window = opts.window,
		default_text = opts.default_text,
	})

	pcall(vim.api.nvim_del_augroup_by_id, group)
	return result
end

-- --------------------------------------------------------------------------
-- Display helpers
-- --------------------------------------------------------------------------

local function show_path_items(buf_id, items, query)
	mini_pick().default_show(buf_id, items, query, { show_icons = false })
end

local ns_id = vim.api.nvim_create_namespace("fff_pick_highlights")

local function show_plain_items(buf_id, items, query)
	local lines = {}
	for _, item in ipairs(items) do
		table.insert(lines, item.display or item.text or tostring(item))
	end

	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

	if not query or query == "" then
		return
	end

	if type(query) == "table" then
		query = table.concat(query)
	end

	if query == "" then
		return
	end

	local MiniPick = mini_pick()
	local picker_opts = MiniPick.get_picker_opts()
	local mode = "plain"
	if picker_opts and picker_opts.window and picker_opts.window.prompt_prefix then
		local prefix = picker_opts.window.prompt_prefix
		if prefix:find("fuzzy") then
			mode = "fuzzy"
		elseif prefix:find("regex") then
			mode = "regex"
		end
	end

	for line_idx, line in ipairs(lines) do
		local _, prefix_end = line:find("^.-:%d+:%d+:")
		prefix_end = prefix_end or 0

		local matches = {}
		if mode == "plain" then
			local start_idx = prefix_end + 1
			local line_lower = line:lower()
			local query_lower = query:lower()
			while true do
				local s, e = line_lower:find(query_lower, start_idx, true)
				if not s then
					break
				end
				table.insert(matches, { s - 1, e })
				start_idx = e + 1
			end
		elseif mode == "regex" then
			local start_idx = prefix_end
			while true do
				local res = vim.fn.matchstrpos(line, query, start_idx)
				local s, e = res[2], res[3]
				if s == -1 then
					break
				end
				if s == e then
					start_idx = start_idx + 1
				else
					table.insert(matches, { s, e })
					start_idx = e
				end
			end
		elseif mode == "fuzzy" then
			local start_idx = prefix_end + 1
			local line_lower = line:lower()
			local query_lower = query:lower()
			local ok = true
			for i = 1, #query do
				local char = query_lower:sub(i, i)
				local idx = line_lower:find(char, start_idx, true)
				if not idx then
					ok = false
					break
				end
				table.insert(matches, { idx - 1, idx })
				start_idx = idx + 1
			end
			if not ok then
				matches = {}
			end
		end

		for _, range in ipairs(matches) do
			vim.api.nvim_buf_add_highlight(buf_id, ns_id, "MiniPickMatchRanges", line_idx - 1, range[1], range[2])
		end
	end
end

-- --------------------------------------------------------------------------
-- Item converters
-- --------------------------------------------------------------------------

local function choose_path_item(item)
	if not item or not item.path or item.path == "" then
		return
	end

	local state = mini_pick().get_picker_state()
	local target_win = state and state.windows and state.windows.target or 0
	if target_win == 0 or not vim.api.nvim_win_is_valid(target_win) then
		target_win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_call(target_win, function()
		vim.cmd("edit " .. vim.fn.fnameescape(item.path))

		if item.lnum ~= nil or item.col ~= nil then
			vim.api.nvim_win_set_cursor(0, {
				item.lnum or 1,
				math.max((item.col or 1) - 1, 0),
			})
		end
	end)
end

local function file_items_from_fff(result)
	local items = type(result) == "table" and (result.items or result) or {}
	local out = {}

	for _, item in ipairs(items) do
		local path
		if type(item) == "table" then
			path = item.path or item.relative_path or item.relativePath
			if not path and type(item.file) == "table" then
				path = item.file.path or item.file.relative_path or item.file.relativePath or item.file.name
			elseif not path and type(item.file) == "string" then
				path = item.file
			end
		else
			path = tostring(item)
		end

		if path then
			local text = path
			if type(item) == "table" then
				text = item.relative_path or item.relativePath or path
			end
			text = vim.fn.fnamemodify(text, ":.")
			table.insert(out, { text = text, path = path })
		end
	end

	return out
end

local function grep_items_from_fff(result)
	local items = type(result) == "table" and (result.items or result.matches or result) or {}
	local out = {}

	for _, item in ipairs(items) do
		if type(item) == "table" then
			local path = item.path or item.relative_path or item.relativePath
			if not path and type(item.file) == "table" then
				path = item.file.path or item.file.relative_path or item.file.relativePath or item.file.name
			elseif not path and type(item.file) == "string" then
				path = item.file
			end

			if path then
				local lnum = tonumber(item.line_number or item.lineNumber or item.lnum or item.line or 1) or 1
				local col
				if item.col ~= nil then
					col = tonumber(item.col)
					if col then
						col = col + 1
					end
				else
					col = tonumber(item.column or item.column_number or item.columnNumber)
				end
				if not col and type(item.match_ranges) == "table" and type(item.match_ranges[1]) == "table" then
					col = tonumber(item.match_ranges[1][1])
					if col then
						col = col + 1
					end
				end
				if not col and type(item.matchRanges) == "table" and type(item.matchRanges[1]) == "table" then
					col = tonumber(item.matchRanges[1][1])
					if col then
						col = col + 1
					end
				end
				col = col or 1

				local text = vim.trim(item.text or item.content or item.line_content or item.lineContent or "")
				local display_path = vim.fn.fnamemodify(path, ":.")
				table.insert(out, {
					text = text,
					display = string.format("%s:%d:%d: %s", display_path, lnum, col, text),
					path = path,
					lnum = lnum,
					col = col,
				})
			end
		end
	end

	return out
end

-- --------------------------------------------------------------------------
-- Picker functions
-- --------------------------------------------------------------------------

local function pick_files_fff()
	local fuzzy = ensure_fff()
	if not fuzzy then
		vim.notify("fff backend not available", vim.log.levels.ERROR)
		return
	end

	local current_file = vim.api.nvim_buf_get_name(0)
	if current_file == "" then
		current_file = nil
	end

	pick_dynamic({
		prompt = "Files",
		show = show_path_items,
		choose = choose_path_item,
		items = function(query)
			local ok, result = pcall(fuzzy.fuzzy_search_files, query or "", 4, current_file, 100, 3, 0, 100)
			if not ok or not result then
				return {}
			end

			return file_items_from_fff(result)
		end,
	})
end

---@alias GrepMode
---| "plain" # Literal substring match. Fastest, treats regex chars literally.
---| "regex" # Regex pattern match. Most expressive, can be slower.
---| "fuzzy" # Approximate match. Great for typos/inexact terms.

---Open grep picker powered by fff.grep.
---@param default_text? string Initial query prefilled in the picker prompt.
---@param grep_mode? GrepMode Search strategy used by fff.grep.search(). Defaults to "plain".
local function pick_grep_fff(default_text, grep_mode)
	local fuzzy = ensure_fff()
	if not fuzzy then
		vim.notify("fff backend not available", vim.log.levels.ERROR)
		return
	end

	local grep_ok, grep = pcall(require, "fff.grep")
	if not grep_ok then
		vim.notify("fff.grep not available", vim.log.levels.ERROR)
		return
	end
	local current_mode = grep_mode or "plain"
	-- Practical defaults:
	-- - plain: search exact text (best for current word/selection)
	-- - regex: search by pattern (character classes, alternation, anchors, etc.)
	-- - fuzzy: search approximate text (tolerates typos/inexact queries)
	local dynamic_opts
	dynamic_opts = {
		prompt = "Grep (" .. current_mode .. ")",
		show = show_plain_items,
		choose = choose_path_item,
		default_text = default_text,
		items = function(query)
			if not query or query == "" then
				return {}
			end

			local ok, result = pcall(grep.search, query, 0, 100, nil, current_mode)
			if not ok or not result then
				return {}
			end

			return grep_items_from_fff(result)
		end,
		mappings = {
			toggle_mode = {
				char = vim.api.nvim_replace_termcodes("<C-g>", true, true, true),
				func = function()
					if current_mode == "plain" then
						current_mode = "fuzzy"
					elseif current_mode == "fuzzy" then
						current_mode = "regex"
					else
						current_mode = "plain"
					end

					local MiniPick = mini_pick()
					MiniPick.set_picker_opts({
						window = {
							prompt_prefix = "Grep (" .. current_mode .. ") ",
						},
					})

					if dynamic_opts.refresh then
						dynamic_opts.refresh()
					end
				end,
			},
		},
	}

	pick_dynamic(dynamic_opts)
end

local function list_colorschemes()
	local current = vim.api.nvim_exec2("colorscheme", { output = true }).output
	local colors = { current }
	local seen = { [current] = true }

	for _, color in ipairs(vim.fn.getcompletion("", "color")) do
		if not seen[color] then
			table.insert(colors, color)
			seen[color] = true
		end
	end

	return colors
end

local function pick_colorschemes()
	local theme = require("config.theme")
	pick_start({
		items = vim.tbl_map(function(color)
			return { text = color }
		end, list_colorschemes()),
		name = "Colorschemes",
		prompt = "Colorscheme",
		choose = function(item)
			if not item or not item.text then
				return
			end

			theme.persist_colorscheme(item.text)
			pcall(vim.cmd.colorscheme, item.text)
		end,
	})
end

local function option_value_to_text(value)
	if type(value) == "table" then
		return vim.inspect(value)
	end

	local text = tostring(value)
	text = text:gsub("\n", "\\n"):gsub("\t", "\\t")
	return text
end

local function pick_vim_options()
	local options = {}
	for _, option in pairs(vim.api.nvim_get_all_options_info()) do
		local ok, value = pcall(vim.api.nvim_get_option_value, option.name, {})
		if ok then
			table.insert(options, {
				text = string.format(
					"%-24s [%s] [%s] %s",
					option.name,
					option.type,
					option.scope,
					option_value_to_text(value)
				),
				name = option.name,
				type = option.type,
				value = value,
			})
		end
	end

	table.sort(options, function(left, right)
		return left.name < right.name
	end)

	pick_start({
		items = options,
		name = "Options",
		prompt = "Options",
		choose = function(item)
			if not item then
				return
			end

			local esc = ""
			if vim.fn.mode() == "i" then
				esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
			end

			local cmd
			if item.type == "boolean" then
				cmd = string.format("%s:set %s!", esc, item.name)
			else
				cmd = string.format("%s:set %s=%s", esc, item.name, tostring(item.value))
			end

			vim.api.nvim_feedkeys(cmd, "m", true)
		end,
	})
end

local function pick_spell_suggestions()
	pick_start({
		items = vim.tbl_map(function(item)
			return { text = item }
		end, vim.fn.spellsuggest(vim.fn.expand("<cword>"))),
		name = "Spelling Suggestions",
		prompt = "Spelling",
		choose = function(item)
			if not item or not item.text or item.text == "" then
				return
			end

			vim.cmd('normal! "_ciw' .. item.text)
			vim.cmd("stopinsert")
		end,
	})
end

local function pick_highlights()
	local highlight_groups = vim.tbl_map(function(group)
		return { text = group }
	end, vim.fn.getcompletion("", "highlight"))
	if #highlight_groups == 0 then
		return
	end

	pick_start({
		items = highlight_groups,
		name = "Highlights",
		prompt = "Highlights",
		preview = function(buf_id, item)
			if not item or not item.text then
				return
			end

			vim.bo[buf_id].filetype = "vim"
			vim.api.nvim_buf_set_lines(
				buf_id,
				0,
				-1,
				false,
				vim.split(vim.fn.execute("highlight " .. item.text), "\n", { trimempty = true })
			)
		end,
		choose = function(item)
			if item and item.text then
				vim.cmd("hi " .. item.text)
			end
		end,
	})
end

local function live_grep_current_buffer()
	local filepath = vim.api.nvim_buf_get_name(0)
	if filepath == "" then
		vim.notify("Current buffer has no file path", vim.log.levels.WARN)
		return
	end

	pick_dynamic({
		name = "Buffer Grep",
		prompt = "Buffer Grep",
		show = show_plain_items,
		choose = choose_path_item,
		items = function(query)
			if not query or query == "" then
				return {}
			end

			local output = vim.fn.systemlist({
				"rg",
				"--line-number",
				"--column",
				"--no-heading",
				"--smart-case",
				"--color=never",
				"--",
				query,
				filepath,
			})
			if vim.v.shell_error > 1 then
				return {}
			end

			local items = {}
			for _, line in ipairs(output) do
				local lnum, col, text = line:match("^(%d+):(%d+):(.*)$")
				if lnum and col then
					table.insert(items, {
						text = string.format("%s:%s: %s", lnum, col, text),
						path = filepath,
						lnum = tonumber(lnum),
						col = tonumber(col),
					})
				end
			end

			return items
		end,
	})
end

local function pick_help_tags()
	mini_pick().builtin.help(nil, {
		window = picker_window("Help"),
	})
end

local function open_command_picker()
	pick_start({
		items = vim.tbl_map(function(command)
			return { text = command }
		end, vim.fn.getcompletion("", "command")),
		name = "Commands",
		prompt = "Commands",
		choose = function(item)
			if item and item.text then
				vim.cmd(item.text)
			end
		end,
	})
end

local function open_buffer_picker()
	local items = {}
	local buffers_output = vim.api.nvim_exec("buffers", true)
	for _, line in ipairs(vim.split(buffers_output, "\n")) do
		local buf_str, name = line:match("^%s*(%d+)"), line:match('"(.*)"')
		local bufnr = tonumber(buf_str)
		if bufnr then
			table.insert(items, { text = name, bufnr = bufnr })
		end
	end

	pick_start({
		items = items,
		prompt = "Buffers",
	})
end

local function location_to_pick_item(location)
	local uri = location.uri or location.targetUri
	local range = location.range or location.targetSelectionRange or location.targetRange
	if not uri or not range or not range.start then
		return nil
	end

	local path = vim.uri_to_fname(uri)
	local lnum = range.start.line + 1
	local col = range.start.character + 1
	return {
		text = string.format("%s:%d:%d", vim.fn.fnamemodify(path, ":."), lnum, col),
		path = path,
		lnum = lnum,
		col = col,
	}
end

local function open_lsp_locations(method, title)
	local clients = vim.lsp.get_clients({ bufnr = 0, method = method })
	if #clients == 0 then
		vim.notify("No LSP client supports " .. method, vim.log.levels.WARN)
		return
	end

	vim.lsp.buf_request_all(0, method, vim.lsp.util.make_position_params(0), function(results)
		vim.schedule(function()
			local items = {}
			local seen = {}

			for _, response in pairs(results or {}) do
				local locations = response and response.result or nil
				if locations then
					if not vim.islist(locations) then
						locations = { locations }
					end

					for _, location in ipairs(locations) do
						local item = location_to_pick_item(location)
						if item then
							local key = string.format("%s:%d:%d", item.path, item.lnum, item.col)
							if not seen[key] then
								seen[key] = true
								table.insert(items, item)
							end
						end
					end
				end
			end

			if #items == 0 then
				vim.notify("No " .. title:lower() .. " found", vim.log.levels.INFO)
				return
			end

			if #items == 1 then
				mini_pick().default_choose(items[1])
				return
			end

			pick_start({
				items = items,
				name = title,
				prompt = title,
				show = show_path_items,
				choose = choose_path_item,
			})
		end)
	end)
end

local function open_definition_picker()
	open_lsp_locations("textDocument/definition", "Definitions")
end

local function open_reference_picker()
	open_lsp_locations("textDocument/references", "References")
end

local function pick_files_fff_in_dir(dir, prompt)
	local fuzzy = ensure_fff()
	if not fuzzy then
		vim.notify("fff backend not available", vim.log.levels.ERROR)
		return
	end

	local original_path = fff_state.base_path
	pcall(fuzzy.restart_index_in_path, dir)
	fff_state.base_path = dir

	pick_dynamic({
		name = prompt,
		prompt = prompt,
		cwd = dir,
		show = show_path_items,
		choose = choose_path_item,
		items = function(query)
			local ok, result = pcall(fuzzy.fuzzy_search_files, query or "", 4, nil, 100, 3, 0, 100)
			if not ok or not result then
				return {}
			end

			return file_items_from_fff(result)
		end,
		on_close = function()
			if original_path then
				pcall(fuzzy.restart_index_in_path, original_path)
				fff_state.base_path = original_path
			end
		end,
	})
end

local function open_nvim_config_files()
	pick_files_fff_in_dir(vim.fn.stdpath("config"), "Nvim Config Files > ")
end

local function open_lazy_data_files()
	pick_files_fff_in_dir(vim.fn.stdpath("data"), "Data Files > ")
end

-- --------------------------------------------------------------------------
-- Picker keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<M-x>", function()
	open_command_picker()
end, { desc = "commands" })

vim.keymap.set("n", "<leader>sc", function()
	pick_colorschemes()
end, { desc = "Search colorscheme" })

vim.keymap.set("n", "<leader><space>", function()
	pick_files_fff()
end, { desc = "Find file" })

vim.keymap.set("n", "<leader>so", function()
	pick_vim_options()
end, { desc = "Search option" })

vim.keymap.set("n", "<leader>ss", function()
	pick_spell_suggestions()
end, { desc = "Search spelling suggestion" })

vim.keymap.set("n", "<leader>sH", function()
	pick_highlights()
end, { desc = "Search highlight group" })

vim.keymap.set("n", "<leader>fn", function()
	open_nvim_config_files()
end, { desc = "Find neovim config files" })

vim.keymap.set("n", "<leader>fp", function()
	open_lazy_data_files()
end, { desc = "Find data files" })

vim.keymap.set("n", "<leader>,", function()
	open_buffer_picker()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>/", function()
	pick_grep_fff()
end, { desc = "Grep" })

vim.keymap.set("n", "<leader>sb", function()
	live_grep_current_buffer()
end, { desc = "Search buffer" })

vim.keymap.set("n", "<leader>sh", function()
	pick_help_tags()
end, { desc = "Search help" })

vim.keymap.set({ "n", "v" }, "<leader>sw", function()
	---@type string
	local mode = vim.fn.mode()
	---@type string[]
	local input = { "" }

	-- Normal mode
	if mode == "n" then
		input = { vim.fn.expand("<cword>") }
	end

	-- Visual mode
	if mode == "v" then
		local _, startrow, startcol = unpack(vim.fn.getpos("v"))
		local _, endrow, endcol = unpack(vim.fn.getpos("."))

		-- This means the visual selection is backwards
		if startrow < endrow or (startrow == endrow and startcol <= endcol) then
			input = vim.api.nvim_buf_get_text(0, startrow - 1, startcol - 1, endrow - 1, endcol, {})
		else
			input = vim.api.nvim_buf_get_text(0, endrow - 1, endcol - 1, startrow - 1, startcol, {})
		end
	end

	-- Visual line mode
	if mode == "V" then
		local _, startrow, _ = unpack(vim.fn.getpos("v"))
		local _, endrow, _ = unpack(vim.fn.getpos("."))

		-- This means the visual selection is backwards
		if startrow > endrow then
			input = vim.api.nvim_buf_get_lines(0, endrow - 1, startrow, true)
		else
			input = vim.api.nvim_buf_get_lines(0, startrow - 1, endrow, true)
		end
	end

	-- Visual block mode
	if mode == "\22" then
		local _, startrow, startcol = unpack(vim.fn.getpos("v"))
		local _, endrow, endcol = unpack(vim.fn.getpos("."))

		local lines = {}
		if startrow > endrow then
			startrow, endrow = endrow, startrow
		end
		if startcol > endcol then
			startcol, endcol = endcol, startcol
		end
		for i = startrow, endrow do
			table.insert(
				lines,
				vim.api.nvim_buf_get_text(0, i - 1, math.min(startcol - 1, endcol), i - 1, math.max(startcol - 1, endcol), {})[1]
			)
		end
		input = lines
	end

	local query = table.concat(input, " ")
	pick_grep_fff(query)
end, { desc = "Search word with grep" })

vim.keymap.set("n", "<leader>'", function()
	mini_pick().builtin.resume()
end, { desc = "Resume last search" })

vim.keymap.set("n", "gd", function()
	open_definition_picker()
end, { desc = "Go to definitions" })

vim.keymap.set("n", "gr", function()
	open_reference_picker()
end, { desc = "Go to references" })
