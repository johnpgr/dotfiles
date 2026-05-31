-- LSP-level config: floating window borders, diagnostics, and oil winbar helper

-- Patch all floating LSP windows to use single-line borders
local lsp_floating_preview_original = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
	opts = opts or {}
	opts.border = "single"
	opts.max_width = opts.max_width or 100
	return lsp_floating_preview_original(contents, syntax, opts, ...)
end

vim.diagnostic.config({
	severity_sort = true,
	float = { border = "single", source = "if_many" },
	underline = true,
})

vim.lsp.semantic_tokens.enable(false)

-- Oil winbar: shows current directory path when in an oil buffer
function _G.get_oil_winbar()
	local result = ""
	local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winid)

	if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ~= "oil" then
		return result
	end

	local dir = require("oil").get_current_dir(bufnr)
	if dir then
		dir = dir:len() > 1 and dir:gsub("/$", "") or dir
		result = dir .. ":"
	else
		result = vim.api.nvim_buf_get_name(bufnr)
	end

	if vim.o.foldcolumn == "0" then
		return result
	else
		return "  " .. result
	end
end
