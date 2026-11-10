local M = {}

local function match_winbar_highlights()
	vim.api.nvim_set_hl(0, "StatusLine", { link = "WinBar" })
	vim.api.nvim_set_hl(0, "StatusLineNC", { link = "WinBar" })
end

match_winbar_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("StatuslineHighlights", { clear = true }),
	callback = match_winbar_highlights,
})

function M.lsp_clients()
	local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
	local names = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = vim.api.nvim_win_get_buf(win) })) do
		names[#names + 1] = client.name
	end
	if #names == 0 then
		return ""
	end
	table.sort(names)
	return "[" .. table.concat(names, ", ") .. "] "
end

vim.o.statusline = vim.o.statusline:gsub("%%=", "%%{v:lua.require('statusline').lsp_clients()}%%=", 1)

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
	group = vim.api.nvim_create_augroup("LspStatusline", { clear = true }),
	-- LspDetach runs before the client is removed from the buffer.
	callback = vim.schedule_wrap(function()
		vim.cmd.redrawstatus()
	end),
})

return M
