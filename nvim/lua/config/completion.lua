-- Completion: mini.completion for LSP popup menu + ghost text on Tab

local M = {}

local min_prefix_length = 1
local ghost_delay_ms = 200
local ghost_namespace = vim.api.nvim_create_namespace("completion-ghost")
local ghost_timer = vim.uv.new_timer()
local ghost_request = 0
local ghost = nil
local ghost_lsp_cancel = nil

vim.o.autocomplete = false
vim.o.autocompletedelay = ghost_delay_ms
vim.o.complete = ".,w,b,u"
vim.o.completeopt = "menuone,noinsert,noselect,nosort,popup"
vim.o.infercase = true
-- Keep the pum narrow so mini.completion's info window has room beside it.
vim.o.pummaxwidth = 60

local function current_prefix()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
	local before_cursor = line:sub(1, col)
	local prefix = vim.fn.matchstr(before_cursor, [[\k*$]])

	return {
		bufnr = vim.api.nvim_get_current_buf(),
		row = row - 1,
		col = col,
		prefix = prefix,
		start_col = col - #prefix,
	}
end

local function word_starts_with(word, prefix)
	if vim.o.ignorecase then
		return word:lower():sub(1, #prefix) == prefix:lower()
	end

	return word:sub(1, #prefix) == prefix
end

local function effective_base(base)
	if type(base) == "string" and base ~= "" then
		local keyword = vim.fn.matchstr(base, [[\k*$]])
		if keyword ~= "" then
			return keyword
		end
		return base
	end

	return current_prefix().prefix
end

local function prefix_filter_items(items, base)
	base = effective_base(base)
	if base == "" then
		return {}
	end

	local filtered = vim.tbl_filter(function(item)
		return word_starts_with(item.filterText or item.label, base)
	end, items)

	table.sort(filtered, function(a, b)
		return (a.sortText or a.label) < (b.sortText or b.label)
	end)

	return filtered
end

local function lsp_insert_text(item)
	local text = (item.textEdit and item.textEdit.newText) or item.insertText or item.filterText or item.label
	if not text or text == "" then
		return ""
	end

	return text:match("^([^\n\r]*)") or text
end

local function ghost_suffix(prefix, item)
	local text = lsp_insert_text(item)
	if text == "" then
		return ""
	end
	if word_starts_with(text, prefix) then
		return text:sub(#prefix + 1)
	end

	return text
end

local function flatten_lsp_items(responses, clients)
	local all_items = {}

	for _, client in ipairs(clients) do
		local result = responses[client.id]
		if not result then
			goto continue
		end

		local items = result.items or result
		if type(items) ~= "table" then
			goto continue
		end

		for _, item in ipairs(items) do
			item.client_id = client.id
			table.insert(all_items, item)
		end

		::continue::
	end

	return all_items
end

local function clear_ghost()
	local bufnr = ghost and ghost.bufnr or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_loaded(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, ghost_namespace, 0, -1)
	end
	ghost = nil
end

local function cancel_lsp_ghost()
	if ghost_lsp_cancel then
		ghost_lsp_cancel()
		ghost_lsp_cancel = nil
	end
end

local function reset_ghost()
	ghost_timer:stop()
	ghost_request = ghost_request + 1
	cancel_lsp_ghost()
	clear_ghost()
end

local function keyword_matches(line)
	local pos = 0

	return function()
		local start_col = vim.fn.match(line, [[\k\+]], pos)
		if start_col < 0 then
			return nil
		end

		local end_col = vim.fn.matchend(line, [[\k\+]], start_col)
		pos = end_col

		return line:sub(start_col + 1, end_col)
	end
end

local function find_buffer_completion(prefix, bufnr)
	local seen = {}

	if vim.api.nvim_buf_is_loaded(bufnr) then
		for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			for word in keyword_matches(line) do
				if not seen[word] and word ~= prefix and word_starts_with(word, prefix) then
					seen[word] = true
					return word
				end
			end
		end
	end
end

local function set_ghost(context, suffix)
	if suffix == "" then
		return
	end

	vim.api.nvim_buf_set_extmark(context.bufnr, ghost_namespace, context.row, context.col, {
		virt_text = { { suffix, "CompletionGhost" } },
		virt_text_pos = "inline",
		hl_mode = "replace",
		priority = 100,
	})

	ghost = {
		bufnr = context.bufnr,
		row = context.row,
		col = context.col,
		prefix = context.prefix,
		text = suffix,
	}
end

local function show_buffer_ghost(context)
	local word = find_buffer_completion(context.prefix, context.bufnr)
	if not word then
		return
	end

	set_ghost(context, word:sub(#context.prefix + 1))
end

local function show_lsp_ghost(context, request)
	cancel_lsp_ghost()

	local clients = vim.lsp.get_clients({ bufnr = context.bufnr, method = vim.lsp.protocol.Methods.textDocument_completion })
	if #clients == 0 then
		show_buffer_ghost(context)
		return
	end

	local responses = {}
	local remaining = #clients
	local request_ids = {}

	local function finish()
		remaining = remaining - 1
		if remaining > 0 then
			return
		end

		ghost_lsp_cancel = nil
		if request ~= ghost_request or vim.api.nvim_get_mode().mode ~= "i" then
			return
		end

		local latest_context = current_prefix()
		if
			latest_context.bufnr ~= context.bufnr
			or latest_context.row ~= context.row
			or latest_context.col ~= context.col
			or latest_context.prefix ~= context.prefix
		then
			return
		end

		local items = prefix_filter_items(flatten_lsp_items(responses, clients), latest_context.prefix)

		for _, item in ipairs(items) do
			local suffix = ghost_suffix(latest_context.prefix, item)
			if suffix ~= "" then
				set_ghost(latest_context, suffix)
				return
			end
		end

		show_buffer_ghost(latest_context)
	end

	for _, client in ipairs(clients) do
		local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
		params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }

		local ok, request_id = client:request("textDocument/completion", params, function(_, result)
			responses[client.id] = result
			finish()
		end, context.bufnr)

		if ok then
			request_ids[client.id] = request_id
		else
			finish()
		end
	end

	ghost_lsp_cancel = function()
		for client_id, request_id in pairs(request_ids) do
			local client = vim.lsp.get_client_by_id(client_id)
			if client then
				client:cancel_request(request_id)
			end
		end
	end
end

local function valid_ghost()
	if not ghost or ghost.bufnr ~= vim.api.nvim_get_current_buf() then
		return nil
	end

	local context = current_prefix()
	if context.row ~= ghost.row or context.col ~= ghost.col or context.prefix ~= ghost.prefix then
		return nil
	end

	return ghost.text
end

local function schedule_ghost()
	clear_ghost()
	ghost_request = ghost_request + 1

	local request = ghost_request
	local context = current_prefix()
	if vim.fn.strchars(context.prefix) < min_prefix_length or vim.fn.pumvisible() == 1 then
		return
	end

	ghost_timer:stop()
	ghost_timer:start(ghost_delay_ms, 0, vim.schedule_wrap(function()
		if request ~= ghost_request or vim.api.nvim_get_mode().mode ~= "i" then
			return
		end

		local latest_context = current_prefix()
		if
			latest_context.bufnr ~= context.bufnr
			or latest_context.row ~= context.row
			or latest_context.col ~= context.col
			or latest_context.prefix ~= context.prefix
		then
			return
		end

		show_lsp_ghost(latest_context, request)
	end))
end

local function trigger_manual_completion()
	reset_ghost()
	MiniCompletion.complete_twostage(true, true)
end

local function setup_keymaps()
	vim.keymap.set("i", "<Tab>", function()
		if vim.fn.pumvisible() == 1 then
			return "<C-y>"
		end

		local ghost_text = valid_ghost()
		if ghost_text then
			clear_ghost()
			return ghost_text
		end

		return "<Tab>"
	end, { expr = true, replace_keycodes = true, desc = "Accept completion or insert tab" })

	vim.keymap.set("i", "<S-Tab>", function()
		if vim.fn.pumvisible() == 1 then
			return "<C-p>"
		end

		return "<S-Tab>"
	end, { expr = true, replace_keycodes = true, desc = "Previous completion item" })

	vim.keymap.set("i", "<C-n>", function()
		if vim.fn.pumvisible() == 1 then
			return "<C-n>"
		end

		trigger_manual_completion()
		return ""
	end, { expr = true, replace_keycodes = true, desc = "Show completion menu or next item" })

	vim.keymap.set("i", "<C-Space>", trigger_manual_completion, { desc = "Show completion menu" })

	vim.keymap.set("i", "<CR>", function()
		if vim.fn.pumvisible() == 1 then
			return "<C-y>"
		end

		return "<CR>"
	end, { expr = true, replace_keycodes = true, desc = "Accept completion or newline" })
end

local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("completion-ghost", { clear = true })

	vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
		group = group,
		callback = schedule_ghost,
	})

	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "CompleteChanged", "CompleteDone" }, {
		group = group,
		callback = reset_ghost,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("completion-lsp", { clear = true }),
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_completion, args.buf) then
				vim.bo[args.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
			end
		end,
	})
end

function M.setup()
	require("mini.completion").setup({
		-- Never auto-open the popup; only show on explicit trigger.
		delay = {
			completion = 10 ^ 7,
			info = 100,
			signature = 50,
		},
		window = {
			info = { height = 20, width = 72, border = "single" },
			signature = { height = 10, width = 72, border = "single" },
		},
		lsp_completion = {
			source_func = "omnifunc",
			auto_setup = false,
			process_items = function(items, base)
				local filtered = prefix_filter_items(items, base)
				return MiniCompletion.default_process_items(filtered, effective_base(base), { filtersort = "none" })
			end,
		},
		fallback_action = "<C-n>",
		mappings = {
			force_twostep = "",
			force_fallback = "",
			scroll_down = "<C-f>",
			scroll_up = "<C-b>",
		},
	})

	setup_keymaps()
	setup_autocmds()

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
			local clients = vim.lsp.get_clients({
				bufnr = bufnr,
				method = vim.lsp.protocol.Methods.textDocument_completion,
			})
			if #clients > 0 then
				vim.bo[bufnr].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
			end
		end
	end
end

return M
