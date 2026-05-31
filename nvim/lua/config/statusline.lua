-- Custom statusline

local ignored_ls = {
	"opencode",
	"copilot",
}

local function lsp_status()
	local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
	if #attached_clients == 0 then
		return ""
	end
	local names = vim.iter(attached_clients)
		:filter(function(client)
			return not vim.tbl_contains(ignored_ls, client.name)
		end)
		:map(function(client)
			local name = client.name:gsub("language.server", "ls")
			return name
		end)
		:totable()
	if #names == 0 then
		return ""
	end
	return "[" .. table.concat(names, ", ") .. "]"
end

local function tab_status()
	return string.format("tab: %d/%d", vim.fn.tabpagenr(), vim.fn.tabpagenr("$"))
end

local function file_status()
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		return "[No Name]"
	end

	return vim.fn.fnamemodify(path, ":."):gsub("%%", "%%%%")
end

local function file_encoding_status()
	local encoding = vim.bo.fenc ~= "" and vim.bo.fenc or vim.o.enc
	return string.lower(encoding)
end

local mode_labels = {
	n = "NORMAL",
	no = "NORMAL",
	v = "VISUAL",
	V = "V-LINE",
	["\22"] = "V-BLOCK",
	s = "SELECT",
	S = "S-LINE",
	i = "INSERT",
	ic = "INSERT",
	R = "REPLACE",
	Rv = "V-REPLACE",
	c = "COMMAND",
	r = "PROMPT",
	t = "TERMINAL",
}

local function mode_status()
	local mode = vim.api.nvim_get_mode().mode

	return mode_labels[mode] or string.upper(mode)
end

function _G.statusline()
	return table.concat({
		"%<",
		file_status(),
		"%h%w%m%r",
		lsp_status(),
		"%=",
		file_encoding_status(),
		tab_status(),
		"col: %c",
		"ln: %l/%L",
		mode_status(),
	}, " ")
end

vim.o.statusline = "%{%v:lua._G.statusline()%}"
vim.o.showtabline = 2
