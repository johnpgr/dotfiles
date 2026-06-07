-- Native Neovim completion

local min_prefix_length = 1
local ghost_delay_ms = 200
local ghost_namespace = vim.api.nvim_create_namespace("native-completion-ghost")
local ghost_timer = vim.uv.new_timer()
local ghost_request = 0
local ghost = nil
local inline_completion_buffers = {}

vim.o.autocomplete = false
vim.o.autocompletedelay = ghost_delay_ms
vim.o.complete = "."
vim.o.completeopt = "menuone,noinsert,noselect,nosort,fuzzy,popup"
vim.o.infercase = true

local lsp_completion = require("vim.lsp.completion")
local merged_request_cancel = nil
local merged_request_id = 0

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

local function has_lsp_completion()
	local bufnr = vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client:supports_method(vim.lsp.protocol.Methods.textDocument_completion, bufnr) then
			return true
		end
	end

	return false
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

local function disable_inline_completion(bufnr)
	if inline_completion_buffers[bufnr] then
		vim.lsp.inline_completion.enable(false, { bufnr = bufnr })
	end
end

local function reset_ghost_completion()
	ghost_timer:stop()
	ghost_request = ghost_request + 1
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

local function lsp_word_keys(lsp_items)
	local keys = {}
	for _, item in ipairs(lsp_items) do
		keys[(item.word or ""):lower()] = true
		if item.abbr and item.abbr ~= "" then
			keys[item.abbr:lower()] = true
		end
	end
	return keys
end

local function collect_buffer_complete_items(prefix, bufnr, lsp_items)
	local items = {}
	local seen = {}
	local lsp_words = lsp_word_keys(lsp_items)
	local buffers = { bufnr }

	for _, other_bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if other_bufnr ~= bufnr and vim.api.nvim_buf_is_loaded(other_bufnr) then
			buffers[#buffers + 1] = other_bufnr
		end
	end

	for _, candidate_bufnr in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(candidate_bufnr) then
			for _, line in ipairs(vim.api.nvim_buf_get_lines(candidate_bufnr, 0, -1, false)) do
				for word in keyword_matches(line) do
					local key = word:lower()
					if not seen[word] and word ~= prefix and word_starts_with(word, prefix) and not lsp_words[key] then
						seen[word] = true
						items[#items + 1] = {
							word = word,
							kind = "Text",
							icase = vim.o.ignorecase and 1 or 0,
						}
					end
				end
			end
		end
	end

	table.sort(items, function(a, b)
		return a.word < b.word
	end)

	return items
end

local function finish_merged_completion(request_id, bufnr, win, clients, responses, cursor_row)
	if request_id ~= merged_request_id then
		return
	end

	merged_request_cancel = nil

	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" and mode ~= "ic" then
		return
	end

	local new_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
	if new_row ~= cursor_row then
		return
	end

	local line = vim.api.nvim_get_current_line()
	local line_to_cursor = line:sub(1, cursor_col)
	local word_boundary = vim.fn.match(line_to_cursor, [[\k*$]])
	local prefix = line:sub(word_boundary + 1, cursor_col)

	local lsp_matches = {}
	local server_start_boundary = nil

	for _, client in ipairs(clients) do
		local response = responses[client.id]
		local result = response and response.result
		if result and #(result.items or result) > 0 then
			local client_matches, tmp_boundary = lsp_completion._convert_results(
				line,
				new_row - 1,
				cursor_col,
				client.id,
				word_boundary,
				nil,
				result,
				client.offset_encoding
			)
			server_start_boundary = tmp_boundary or server_start_boundary
			vim.list_extend(lsp_matches, client_matches)
		end
	end

	local start_col = (server_start_boundary or word_boundary) + 1
	local buffer_items = collect_buffer_complete_items(prefix, bufnr, lsp_matches)
	local matches = vim.list_extend(lsp_matches, buffer_items)

	if #matches > 1 then
		table.sort(matches, lsp_first_cmp)
	end

	if #matches > 0 then
		vim.fn.complete(start_col, matches)
	end
end

local function show_merged_completion()
	reset_ghost_completion()

	if merged_request_cancel then
		merged_request_cancel()
		merged_request_cancel = nil
	end

	local request_id = merged_request_id + 1
	merged_request_id = request_id

	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
	local line = vim.api.nvim_get_current_line()
	local line_to_cursor = line:sub(1, cursor_col)
	local word_boundary = vim.fn.match(line_to_cursor, [[\k*$]])
	local prefix = line:sub(word_boundary + 1, cursor_col)

	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = vim.lsp.protocol.Methods.textDocument_completion })
	if #clients == 0 then
		if vim.fn.strchars(prefix) >= min_prefix_length then
			local buffer_items = collect_buffer_complete_items(prefix, bufnr, {})
			if #buffer_items > 0 then
				vim.fn.complete(word_boundary + 1, buffer_items)
			end
		end
		return
	end

	local responses = {}
	local remaining = #clients
	local request_ids = {}

	local function on_client_done()
		remaining = remaining - 1
		if remaining > 0 then
			return
		end
		finish_merged_completion(request_id, bufnr, win, clients, responses, cursor_row)
	end

	for _, client in ipairs(clients) do
		local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
		params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }

		local ok, request_id_lsp = client:request("textDocument/completion", params, function(_, result)
			responses[client.id] = { result = result }
			on_client_done()
		end, bufnr)

		if ok then
			request_ids[client.id] = request_id_lsp
		else
			on_client_done()
		end
	end

	merged_request_cancel = function()
		for client_id, rid in pairs(request_ids) do
			local client = vim.lsp.get_client_by_id(client_id)
			if client then
				client:cancel_request(rid)
			end
		end
	end
end

local function complete_menu(keys)
	if vim.fn.pumvisible() == 1 then
		return keys
	end

	if has_lsp_completion() then
		show_merged_completion()
		return ""
	end

	return keys
end

local function find_buffer_completion(prefix, bufnr)
	local seen = {}
	local buffers = { bufnr }

	for _, other_bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if other_bufnr ~= bufnr and vim.api.nvim_buf_is_loaded(other_bufnr) then
			buffers[#buffers + 1] = other_bufnr
		end
	end

	for _, candidate_bufnr in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(candidate_bufnr) then
			for _, line in ipairs(vim.api.nvim_buf_get_lines(candidate_bufnr, 0, -1, false)) do
				for word in keyword_matches(line) do
					if not seen[word] and word ~= prefix and word_starts_with(word, prefix) then
						seen[word] = true
						return word
					end
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

		if inline_completion_buffers[latest_context.bufnr] then
			vim.lsp.inline_completion.enable(true, { bufnr = latest_context.bufnr })
			return
		end

		show_buffer_ghost(latest_context)
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

vim.keymap.set("i", "<C-n>", function()
	return complete_menu("<C-n>")
end, { expr = true, replace_keycodes = true, desc = "Next completion item" })

vim.keymap.set("i", "<C-p>", function()
	return complete_menu("<C-p>")
end, { expr = true, replace_keycodes = true, desc = "Previous completion item" })

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
