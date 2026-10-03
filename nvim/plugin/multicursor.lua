local ns = vim.api.nvim_create_namespace("nvim.multicursor")

local function add_matches(all)
	local ok, word = pcall(vim.fn.expand, "<cword>")
	if not ok or word == "" then
		return
	end

	-- Match the exact keyword even when ordinary searches use 'ignorecase'.
	local pattern = "\\C\\V\\<" .. vim.fn.escape(word, "\\") .. "\\>"
	local matches = vim.fn.matchbufline(vim.api.nvim_get_current_buf(), pattern, 1, "$")
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local current, offset
	for i, match in ipairs(matches) do
		if match.lnum == row and col >= match.byteidx and col < match.byteidx + #word then
			current, offset = i, col - match.byteidx
			break
		end
	end
	if not current then
		return
	end

	local occupied = { [row .. ":" .. col] = true }
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
		occupied[(mark[2] + 1) .. ":" .. mark[3]] = true
	end

	for step = 1, #matches - 1 do
		local match = matches[(current + step - 1) % #matches + 1]
		local target_col = match.byteidx + offset
		if not occupied[match.lnum .. ":" .. target_col] then
			vim.api.nvim_mcursor(0, { match.lnum, target_col })
			vim.cmd.normal({ "1q=", bang = true })
			if not all then
				return
			end
		end
	end
end

vim.keymap.set("n", "<C-n>", function()
	add_matches(false)
end, { desc = "Multicursor: add next word match" })

vim.keymap.set("n", "<C-M-n>", function()
	add_matches(true)
end, { desc = "Multicursor: add all word matches" })
