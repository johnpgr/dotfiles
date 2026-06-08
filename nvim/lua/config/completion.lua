-- Native Neovim completion

local min_prefix_length = 1
local ghost_delay_ms = 200
local ghost_namespace = vim.api.nvim_create_namespace("native-completion-ghost")
local ghost_timer = vim.uv.new_timer()
local ghost_request = 0
local ghost = nil
local ghost_lsp_cancel = nil
local inline_completion_buffers = {}

vim.o.autocomplete = false
vim.o.autocompletedelay = ghost_delay_ms
vim.o.complete = "o,."
vim.o.completeopt = "menuone,noinsert,noselect,nosort,fuzzy,popup"
vim.o.infercase = true
vim.o.pummaxwidth = 80

local lsp_completion = require("vim.lsp.completion")

local function feedkeys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

local function is_lsp_item(item)
	return vim.tbl_get(item, "user_data", "nvim", "lsp", "client_id") ~= nil
end

local function lsp_first_cmp(a, b)
	local a_lsp, b_lsp = is_lsp_item(a), is_lsp_item(b)
	if a_lsp ~= b_lsp then
		return a_lsp
	end

	local score_a = a._fuzzy_score or 0
	local score_b = b._fuzzy_score or 0
	if score_a ~= score_b then
		return score_a > score_b
	end

	return (a.word or "") < (b.word or "")
end

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

local function disable_inline_completion(bufnr)
	if inline_completion_buffers[bufnr] then
		vim.lsp.inline_completion.enable(false, { bufnr = bufnr })
	end
end

local function reset_ghost_completion()
	ghost_timer:stop()
	ghost_request = ghost_request + 1
	cancel_lsp_ghost()
	clear_ghost()
	disable_inline_completion(vim.api.nvim_get_current_buf())
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

local function word_starts_with(word, prefix)
	if vim.o.ignorecase then
		return word:lower():sub(1, #prefix) == prefix:lower()
	end

	return word:sub(1, #prefix) == prefix
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

local function show_buffer_ghost(context)
	local word = find_buffer_completion(context.prefix, context.bufnr)
	if not word then
		return
	end

	local suffix = word:sub(#context.prefix + 1)
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

local function set_ghost(context, suffix)
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

		local line = vim.api.nvim_buf_get_lines(context.bufnr, context.row, context.row + 1, false)[1] or ""
		local lsp_matches = {}

		for _, client in ipairs(clients) do
			local result = responses[client.id]
			if result and #(result.items or result) > 0 then
				local client_matches = lsp_completion._convert_results(
					line,
					context.row,
					context.col,
					client.id,
					context.start_col,
					nil,
					result,
					client.offset_encoding
				)
				vim.list_extend(lsp_matches, client_matches)
			end
		end

		if #lsp_matches > 1 then
			table.sort(lsp_matches, lsp_first_cmp)
		end

		for _, item in ipairs(lsp_matches) do
			local word = item.word or item.abbr or ""
			if word ~= context.prefix and word_starts_with(word, context.prefix) then
				local suffix = word:sub(#context.prefix + 1)
				if suffix ~= "" then
					set_ghost(context, suffix)
					return
				end
			end
		end

		show_buffer_ghost(context)
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

local function lsp_completion_clients(bufnr)
	return vim.lsp.get_clients({ bufnr = bufnr, method = vim.lsp.protocol.Methods.textDocument_completion })
end

local function lsp_has_completion_items(result)
	if not result then
		return false
	end

	return #(result.items or result) > 0
end

local function trigger_buffer_completion()
	local bufnr = vim.api.nvim_get_current_buf()
	local complete = vim.bo.complete

	vim.bo.complete = "."
	feedkeys("<C-e><C-n>")
	vim.defer_fn(function()
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.bo[bufnr].complete = complete
		end
	end, 50)
end

local function with_lsp_only_completion(callback)
	local bufnr = vim.api.nvim_get_current_buf()
	local complete = vim.bo.complete

	vim.bo.complete = "o"
	callback()
	vim.defer_fn(function()
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.bo[bufnr].complete = complete
		end
	end, 50)
end

local function trigger_lsp_completion()
	with_lsp_only_completion(function()
		feedkeys("<C-e><C-x><C-o>")
	end)
end

local manual_completion_request = 0

local function trigger_manual_completion()
	reset_ghost_completion()

	if vim.fn.pumvisible() == 1 then
		feedkeys("<C-n>")
		return
	end

	local request = manual_completion_request + 1
	manual_completion_request = request

	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local row, col = unpack(vim.api.nvim_win_get_cursor(win))
	local clients = lsp_completion_clients(bufnr)
	if #clients == 0 then
		trigger_buffer_completion()
		return
	end

	local remaining = #clients
	local has_lsp_items = false

	local function finish()
		remaining = remaining - 1
		if remaining > 0 then
			return
		end

		if manual_completion_request ~= request or not vim.api.nvim_get_mode().mode:find("^i") then
			return
		end

		local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(win))
		if current_row ~= row or current_col ~= col then
			return
		end

		if has_lsp_items then
			trigger_lsp_completion()
		else
			trigger_buffer_completion()
		end
	end

	for _, client in ipairs(clients) do
		local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
		params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }

		local ok = client:request("textDocument/completion", params, function(_, result)
			if lsp_has_completion_items(result) then
				has_lsp_items = true
			end
			finish()
		end, bufnr)

		if not ok then
			finish()
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
	disable_inline_completion(vim.api.nvim_get_current_buf())
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

local group = vim.api.nvim_create_augroup("native-completion", { clear = true })

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
	group = group,
	callback = schedule_ghost,
})

vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "CompleteChanged", "CompleteDone" }, {
	group = group,
	callback = reset_ghost_completion,
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("native-lsp-completion", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_completion, args.buf) then
			vim.lsp.completion.enable(true, client.id, args.buf)
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, args.buf) then
			inline_completion_buffers[args.buf] = true
			vim.lsp.inline_completion.enable(false, { bufnr = args.buf, client_id = client.id })
		end
	end,
})

vim.keymap.set("i", "<Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-y>"
	end

	if vim.lsp.inline_completion.get({ bufnr = 0 }) then
		return ""
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
