vim.g.emacs_tab = false
vim.g.treesitter_enabled = true
vim.g.icons_enabled = true
vim.g.c_syntax_for_h = true
vim.g.mapleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.o.cursorline = false
vim.o.number = false
vim.o.relativenumber = false
vim.o.confirm = true
vim.o.wrap = false
vim.o.inccommand = "split"
vim.o.swapfile = false
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.list = false
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.signcolumn = "no"
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.mouse = "nv"
vim.o.breakindent = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.termguicolors = true
vim.o.updatetime = 200
vim.o.undofile = true
vim.o.exrc = true
vim.o.secure = true
vim.o.cmdheight = 0
vim.o.spelllang = "en,pt_br"
vim.opt.clipboard = "unnamedplus"
vim.opt.diffopt:append("linematch:60")
vim.treesitter.language.register("c", "cpp")
vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]

require "vim._core.ui2".enable {}

local is_neovide = vim.g.neovide ~= nil

if vim.fn.has("mac") == 1 and not vim.env.SDKROOT and vim.fn.executable("xcrun") == 1 then
	local sdkroot = vim.trim(vim.fn.system("xcrun --show-sdk-path"))
	if vim.v.shell_error == 0 and sdkroot ~= "" then
		vim.env.SDKROOT = sdkroot
	end
end

local editorconfig = [[
# EditorConfig is awesome: https://editorconfig.org

# top-most EditorConfig file
root = true

# Unix-style newlines with a newline ending every file
[*]
end_of_line = lf
insert_final_newline = true

# Matches multiple files with brace expansion notation
# Set default charset
[*.{js,py}]
charset = utf-8

# 4 space indentation
[*.py]
indent_style = space
indent_size = 4

# Tab indentation (no size specified)
[Makefile]
indent_style = tab

# Indentation override for all JS under lib directory
[lib/**.js]
indent_style = space
indent_size = 2

# Matches the exact files either package.json or .travis.yml
[{package.json,.travis.yml}]
indent_style = space
indent_size = 2
]]

local function apply_colorscheme_overrides()
	local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
	local cursorline_hl = vim.api.nvim_get_hl(0, { name = "CursorLine" })
	local conceal_hl = vim.api.nvim_get_hl(0, { name = "Conceal" })
	local hint_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticHint" })
	local warn_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn" })
	local err_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticError" })
	local matchparen_hl = vim.api.nvim_get_hl(0, { name = "MatchParen" })
	local muted_color = (conceal_hl and conceal_hl.fg)
	local accent_color = (hint_hl and hint_hl.fg) or (warn_hl and warn_hl.fg) or muted_color

	vim.api.nvim_set_hl(0, "TabLineFill", {
		fg = normal_hl.fg,
		bg = cursorline_hl.bg,
	})
	vim.api.nvim_set_hl(0, "TabLine", {
		fg = normal_hl.fg,
		bg = cursorline_hl.bg,
	})
	vim.api.nvim_set_hl(0, "TabLineSel", {
		fg = warn_hl.fg,
		bg = cursorline_hl.bg,
		bold = true,
	})
	vim.api.nvim_set_hl(
		0,
		"MatchParen",
		vim.tbl_extend("force", matchparen_hl or {}, {
			fg = (err_hl and err_hl.fg) or accent_color,
			underline = false,
			undercurl = false,
			underdouble = false,
			underdotted = false,
			underdashed = false,
		})
	)
	vim.api.nvim_set_hl(0, "Visual", { reverse = true })
	vim.api.nvim_set_hl(0, "VisualNOS", { reverse = true })

	vim.api.nvim_set_hl(0, "CursorLineFold", { link = "CursorLine" })
	vim.api.nvim_set_hl(0, "WinSeparator", { link = "Conceal" })
	vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
	vim.api.nvim_set_hl(0, "MsgArea", {
		fg = normal_hl.fg,
		bg = cursorline_hl.bg,
	})
	vim.api.nvim_set_hl(0, "MsgSeparator", {
		fg = normal_hl.fg,
		bg = cursorline_hl.bg,
	})

	for _, group in ipairs({
		"@number",
		"@operator",
		"@constant",
		"@punctuation.bracket",
		"@punctuation.delimiter",
		"@variable",
		"@variable.parameter",
		"@property",
		"@constructor",
	}) do
		vim.api.nvim_set_hl(0, group, { fg = normal_hl.fg })
	end

	for _, group in ipairs({
		"LspReferenceText",
		"LspReferenceRead",
		"LspReferenceWrite",
	}) do
		vim.api.nvim_set_hl(0, group, {
			sp = muted_color,
			underline = true,
		})
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = apply_colorscheme_overrides,
})

local theme_uv = vim.uv or vim.loop
local colorscheme_file = vim.fn.stdpath("config") .. "/.colorscheme"
local theme_state_file = vim.fs.joinpath(vim.loop.os_homedir(), ".dotfiles", ".theme_state")
local theme_state_dir = vim.fs.dirname(theme_state_file)
local theme_state_name = vim.fs.basename(theme_state_file)

local theme_state_watcher
local theme_state_timer
local last_applied_mode
local theme_apply_in_progress = false
local theme_sync_pending = false
local apply_theme_state

local function close_handle(handle)
	if handle and not handle:is_closing() then
		handle:close()
	end
end

local function read_theme_state()
	local f = io.open(theme_state_file, "r")
	if not f then
		return nil
	end

	local mode = f:read("*all")
	f:close()

	mode = mode and vim.trim(mode) or ""
	if mode == "dark" or mode == "light" then
		return mode
	end

	return nil
end

local initial_theme_state = read_theme_state()
if initial_theme_state then
	vim.o.background = initial_theme_state
	last_applied_mode = initial_theme_state
end

local function current_colorscheme()
	local colors_name = vim.g.colors_name
	if type(colors_name) == "string" and colors_name ~= "" then
		return colors_name
	end

	return nil
end

local sync_theme_state

local function apply_theme_state_now(mode, opts)
	opts = opts or {}
	if mode ~= "dark" and mode ~= "light" then
		return false
	end

	if theme_apply_in_progress then
		theme_sync_pending = true
		return false
	end

	if mode == last_applied_mode and not opts.force then
		return false
	end

	theme_apply_in_progress = true

	local ok, err = pcall(function()
		vim.o.background = mode

		if opts.reapply_colorscheme ~= false then
			local colors_name = current_colorscheme()
			if colors_name then
				vim.cmd.colorscheme(colors_name)
			end
		end
	end)

	theme_apply_in_progress = false

	if ok then
		last_applied_mode = mode
	else
		vim.notify("Unable to apply theme state: " .. err, vim.log.levels.WARN)
	end

	if theme_sync_pending then
		theme_sync_pending = false
		vim.schedule(function()
			sync_theme_state({ force = true })
		end)
	end

	return ok
end

sync_theme_state = function(opts)
	return apply_theme_state(read_theme_state(), opts)
end

local function debounce_theme_sync()
	if not theme_uv or not theme_uv.new_timer then
		sync_theme_state()
		return
	end

	if theme_state_timer and theme_state_timer:is_closing() then
		theme_state_timer = nil
	end

	if not theme_state_timer then
		theme_state_timer = theme_uv.new_timer()
	end

	if not theme_state_timer then
		sync_theme_state()
		return
	end

	theme_state_timer:stop()
	theme_state_timer:start(
		100,
		0,
		vim.schedule_wrap(function()
			sync_theme_state()
		end)
	)
end

local function persist_colorscheme(colors_name)
	if type(colors_name) == "table" then
		colors_name = colors_name.text
	end

	if type(colors_name) ~= "string" or colors_name == "" then
		vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
		return
	end

	local f = io.open(colorscheme_file, "w")
	if not f then
		vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
		return
	end

	f:write(colors_name)
	f:close()
end

local function load_persisted_colorscheme()
	local f = io.open(colorscheme_file, "r")
	if f then
		local persisted = f:read("*all")
		f:close()

		persisted = persisted and vim.trim(persisted) or ""
		if persisted ~= "" then
			local ok, err = pcall(vim.cmd.colorscheme, persisted)
			if ok then
				vim.api.nvim_exec_autocmds("ColorScheme", { pattern = persisted })
			else
				vim.notify(
					string.format("Unable to load persisted colorscheme '%s': %s", persisted, err),
					vim.log.levels.WARN
				)
			end
		end
	end

	sync_theme_state({ force = true })
end

apply_theme_state = function(mode, opts)
	if mode ~= "dark" and mode ~= "light" then
		return false
	end

	if vim.in_fast_event() then
		vim.schedule(function()
			apply_theme_state_now(mode, opts)
		end)
		return true
	end

	return apply_theme_state_now(mode, opts)
end

local function start_theme_state_watcher()
	if theme_state_watcher or not theme_uv or not theme_uv.new_fs_event then
		return false
	end

	theme_state_watcher = theme_uv.new_fs_event()
	if not theme_state_watcher then
		return false
	end

	local ok, err = theme_state_watcher:start(theme_state_dir, {}, function(watch_err, filename)
		if watch_err then
			vim.schedule(function()
				vim.notify("Theme watcher error: " .. watch_err, vim.log.levels.WARN)
			end)
			return
		end

		if filename and filename ~= theme_state_name then
			return
		end

		debounce_theme_sync()
	end)

	if not ok then
		close_handle(theme_state_watcher)
		theme_state_watcher = nil
		vim.notify("Unable to start theme watcher: " .. err, vim.log.levels.WARN)
		return false
	end

	return true
end

local function stop_theme_state_watcher()
	if theme_state_timer then
		theme_state_timer:stop()
		close_handle(theme_state_timer)
		theme_state_timer = nil
	end

	if theme_state_watcher then
		theme_state_watcher:stop()
		close_handle(theme_state_watcher)
		theme_state_watcher = nil
	end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		stop_theme_state_watcher()
	end,
})

local ignored_ls = {
	"opencode",
	"copilot",
}

-- Statusline
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

function _G.statusline()
	return table.concat({
		"%f",
		"%h%w%m%r",
		"%=",
		lsp_status(),
		" %-14(%l,%c%V%)",
		"%P",
	}, " ")
end

vim.o.statusline = "%{%v:lua._G.statusline()%}"
vim.o.showtabline = 2

-- CMDLINE AUTOCOMPLETION (see :h cmdline-autocompletion)

-- Core: show a popup menu of suggestions as you type on : / ?
vim.api.nvim_create_autocmd("CmdlineChanged", {
	pattern = { ":", "/", "?" },
	callback = function()
		vim.fn.wildtrigger()
	end,
})

vim.opt.wildmode = "noselect:lastused,full"
vim.opt.wildoptions = "pum"

-- Keep <Up>/<Down> for history when the wildmenu is not active
vim.keymap.set("c", "<Up>", function()
	return vim.fn.wildmenumode() == 1 and [[<C-E><Up>]] or [[<Up>]]
end, { expr = true })

vim.keymap.set("c", "<Down>", function()
	return vim.fn.wildmenumode() == 1 and [[<C-E><Down>]] or [[<Down>]]
end, { expr = true })

-- Smaller popup during search (8 lines), restored on leave
vim.api.nvim_create_autocmd("CmdlineEnter", {
	pattern = { "/", "?" },
	callback = function()
		vim.opt.pumheight = 8
	end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
	pattern = { "/", "?" },
	callback = function()
		vim.opt.pumheight = vim.go.pumheight
	end,
})

vim.keymap.set("n", "<leader>w", "<cmd>update<cr>", { desc = "Write" })
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
vim.keymap.set("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
vim.keymap.set("n", "<C-S-t>", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<C-S-w>", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Buffer next" })
vim.keymap.set("n", "<S-Tab>", "<cmd>bprev<cr>", { desc = "Buffer prev" })
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlights" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>I", "<cmd>Inspect<cr>", { desc = "Inspect" })
vim.keymap.set("n", "yig", ":%y<CR>", { desc = "Yank buffer" })
vim.keymap.set("n", "vig", "ggVG", { desc = "Visual select buffer" })
vim.keymap.set("n", "cig", ":%d<CR>i", { desc = "Change buffer" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search result" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Previous diagnostic" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("v", "<", "<gv", { desc = "Decrease indent" })
vim.keymap.set("v", ">", ">gv", { desc = "Increase indent" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })

-- Toggle keybinds
vim.keymap.set("n", "<leader>tl", function()
	if vim.o.number and vim.o.relativenumber then
		vim.o.relativenumber = false
	elseif vim.o.number and not vim.o.relativenumber then
		vim.o.number = false
	else
		vim.o.number = true
		vim.o.relativenumber = true
	end
end, { desc = "Line numbers" })

vim.keymap.set("n", "<leader>tI", function()
	if vim.o.expandtab then
		vim.o.expandtab = false
		vim.notify("Indent style: tabs", vim.log.levels.INFO)
	else
		vim.o.expandtab = true
		vim.notify("Indent style: spaces", vim.log.levels.INFO)
	end
end, { desc = "Indent style" })

vim.keymap.set("n", "<leader>ts", function()
	if vim.o.signcolumn == "no" then
		vim.o.signcolumn = "yes"
	else
		vim.o.signcolumn = "no"
	end
end, { desc = "Sign column" })

vim.keymap.set("n", "<leader>tc", function()
	if vim.o.colorcolumn == "" then
		vim.o.colorcolumn = "80"
	else
		vim.o.colorcolumn = ""
	end
end, { desc = "Color column" })

-- Yank keymaps
vim.keymap.set("n", "<leader>fy", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	vim.fn.setreg("+", filepath)
	print("Copied path: " .. filepath)
end, { desc = "Yank filepath" })
vim.keymap.set("n", "<leader>fY", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	local relative_path = vim.fn.fnamemodify(filepath, ":~:.")
	vim.fn.setreg("+", relative_path)
	print("Copied path: " .. relative_path)
end, { desc = "Yank filepath from workspace" })

-- Insert keymaps
vim.keymap.set("n", "<leader>if", function()
	local filename = vim.fn.expand("%:t")
	if filename == "" then
		return
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. filename .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filename })
end, { desc = "File name" })
vim.keymap.set("n", "<leader>iF", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. filepath .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filepath })
end, { desc = "File path" })

vim.keymap.set("n", "<leader>ie", function()
	local editor_config = editorconfig
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1 -- 0-indexed
	local lines = vim.split(editor_config, "\n", { plain = true })
	vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
	if #lines == 1 then
		vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
	else
		vim.api.nvim_win_set_cursor(0, { row + #lines, #lines[#lines] })
	end
end, { desc = "Editorconfig" })

-- LSP keymaps
-- vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })
vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>lf", function()
	require("conform").format({ async = true })
end, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Diagnostic" })
vim.keymap.set("n", "<leader>ll", vim.diagnostic.setqflist, { desc = "Diagnostic List" })

-- Quickfix keymaps
vim.keymap.set("n", "]q", function()
	local qf_list = vim.fn.getqflist()
	local qf_length = #qf_list
	if qf_length == 0 then
		return
	end

	local current_idx = vim.fn.getqflist({ idx = 0 }).idx
	if current_idx >= qf_length then
		vim.cmd("cfirst")
	else
		vim.cmd("cnext")
	end
	vim.cmd("copen")
end, { desc = "Next quickfix item" })

vim.keymap.set("n", "[q", function()
	local qf_list = vim.fn.getqflist()
	local qf_length = #qf_list
	if qf_length == 0 then
		return
	end

	local current_idx = vim.fn.getqflist({ idx = 0 }).idx
	if current_idx <= 1 then
		vim.cmd("clast")
	else
		vim.cmd("cprevious")
	end
	vim.cmd("copen")
end, { desc = "Previous quickfix item" })

vim.keymap.set("n", "]e", function()
	require("compile-mode").next_error()
end, { desc = "Next error" })

vim.keymap.set("n", "[e", function()
	require("compile-mode").prev_error()
end, { desc = "Previous error" })

vim.keymap.set("n", "<leader>m", function()
	vim.print("test")
	if vim.bo.filetype == "oil" then
		vim.g.compilation_directory = require("oil").get_current_dir()
	end
	require("compile-mode").compile()
end, { desc = "Compile" })

vim.keymap.set("n", "<leader>M", function()
	if vim.bo.filetype == "oil" then
		vim.g.compilation_directory = require("oil").get_current_dir()
	end
	require("compile-mode").compile({
		smods = {
			vertical = true,
		},
	})
end, { desc = "Compile (vertical)" })

vim.keymap.set("n", "<leader>r", function()
	require("compile-mode").recompile()
end, { desc = "Recompile" })

local function nav_hunk(direction)
	if vim.wo.diff then
		local key = direction == "next" and "]c" or "[c"
		vim.cmd.normal({ key, bang = true })
		return
	end

	local popup = require("gitsigns.popup")
	popup.close("hunk")

	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.api.nvim_win_get_config(w).relative == "" then
				vim.api.nvim_set_current_win(w)
				break
			end
		end
	end

	local gitsigns = require("gitsigns")
	local bufnr = vim.api.nvim_get_current_buf()
	local hunks = gitsigns.get_hunks(bufnr) or {}
	if #hunks == 0 then
		return
	end

	local cur = vim.api.nvim_win_get_cursor(0)[1]
	local target

	if direction == "next" then
		for _, h in ipairs(hunks) do
			if h.added.start > cur then
				target = h.added.start
				break
			end
		end
		if not target then
			target = hunks[1].added.start
		end
	else
		for i = #hunks, 1, -1 do
			if hunks[i].added.start < cur then
				target = hunks[i].added.start
				break
			end
		end
		if not target then
			target = hunks[#hunks].added.start
		end
	end

	target = math.max(1, math.min(target, vim.api.nvim_buf_line_count(bufnr)))
	vim.api.nvim_win_set_cursor(0, { target, 0 })

	vim.schedule(function()
		gitsigns.preview_hunk()
	end)
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
	callback = function()
		vim.bo.filetype = "image"
	end,
})

-- LSP floating window config
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

local uv = vim.uv or vim.loop
local fff_state = {
	initialized = false,
	base_path = nil,
	fuzzy = nil,
}

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
		return
	end

	local MiniPick = mini_pick()
	vim.schedule(function()
		if MiniPick.get_picker_opts() == nil then
			return
		end

		MiniPick.set_picker_query(split_query_text(text))
	end)
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

local function pick_start(opts)
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
		mappings = opts.mappings,
		options = opts.options,
		window = picker_window(opts.prompt, opts.window),
	})

	set_picker_default_text(opts.default_text)
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

		MiniPick.set_picker_items(items or {}, { querytick = querytick })
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

local function show_path_items(buf_id, items, query)
	mini_pick().default_show(buf_id, items, query, { show_icons = false })
end

local function show_plain_items(buf_id, items)
	local lines = {}
	for _, item in ipairs(items) do
		table.insert(lines, item.text or tostring(item))
	end

	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

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
		vim.api.nvim_win_set_cursor(0, {
			item.lnum or 1,
			math.max((item.col or 1) - 1, 0),
		})
	end)
end

local function file_items_from_fff(result)
	local items = type(result) == "table" and (result.items or result) or {}
	local out = {}

	for _, item in ipairs(items) do
		local text = item.relative_path or item.path or tostring(item)
		local path = item.path or text
		table.insert(out, { text = text, path = path })
	end

	return out
end

local function grep_items_from_fff(result)
	local items = type(result) == "table" and (result.items or result.matches or result) or {}
	local out = {}

	for _, item in ipairs(items) do
		local path = item.path or item.file or ""
		local lnum = tonumber(item.line_number or item.lnum or item.line or 1) or 1
		local col = tonumber(item.col or item.column or 1) or 1
		local text = vim.trim(item.text or item.content or item.line_content or "")
		local filename = vim.fn.fnamemodify(path, ":t")
		table.insert(out, {
			text = string.format("%s:%d:%d: %s", filename, lnum, col, text),
			path = path,
			lnum = lnum,
			col = col,
		})
	end

	return out
end

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
	grep_mode = grep_mode or "plain"
	pick_dynamic({
		prompt = "Grep",
		show = show_plain_items,
		choose = choose_path_item,
		default_text = default_text,
		items = function(query)
			if not query or query == "" then
				return {}
			end

			local ok, result = pcall(grep.search, query, 0, 100, nil, grep_mode)
			if not ok or not result then
				return {}
			end

			return grep_items_from_fff(result)
		end,
	})
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

			persist_colorscheme(item.text)
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

local function get_grep_string_query(opts)
	opts = opts or {}

	local word
	local visual = vim.fn.mode() == "v"

	if visual then
		local saved_reg = vim.fn.getreg("v")
		vim.cmd([[noautocmd sil norm! "vy]])
		local selection = vim.fn.getreg("v")
		vim.fn.setreg("v", saved_reg)
		word = vim.F.if_nil(opts.search, selection)
	else
		word = vim.F.if_nil(opts.search, vim.fn.expand("<cword>"))
	end

	return tostring(word)
end

local function grep_string_with_fff(opts)
	opts = opts or {}
	local word = get_grep_string_query(opts)
	pick_grep_fff(word, opts.use_regex and "regex" or "plain")
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
	mini_pick().builtin.buffers(nil, {
		window = picker_window("Buffers"),
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

vim.filetype.add({
	extension = {
		hlsl = "hlsl",
		m = "objc",
	},
})

vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp-document-highlight", { clear = true }),
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client:supports_method("textDocument/documentHighlight", event.buf) then
			local augroup = vim.api.nvim_create_augroup("lsp-document-highlight-" .. event.buf, { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = augroup,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = augroup,
				callback = vim.lsp.buf.clear_references,
			})
			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("lsp-document-highlight-detach-" .. event.buf, { clear = true }),
				buffer = event.buf,
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = augroup, buffer = event2.buf })
				end,
			})
		end
	end,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim with plugins from lua/plugins.lua
require("lazy").setup("plugins", {
	defaults = {
		lazy = true, -- All plugins are lazy-loaded by default
	},
	rocks = {
		enabled = false, -- Disable luarocks integration (image.nvim will use magick_cli instead)
	},
	install = {
		colorscheme = { "default" },
	},
	checker = {
		enabled = false, -- Don't auto-check for updates
	},
	change_detection = {
		enabled = true,
		notify = false,
	},
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"matchit",
				"netrw",
				"netrwPlugin",
				"netrwFileHandlers",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})

load_persisted_colorscheme()
start_theme_state_watcher()

vim.keymap.set("n", "]h", function()
	nav_hunk("next")
end, { desc = "Next hunk" })
vim.keymap.set("n", "[h", function()
	nav_hunk("prev")
end, { desc = "Previous hunk" })
vim.keymap.set("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>gB", "<cmd>Gitsigns blame<cr>", { desc = "Git blame" })
vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
vim.keymap.set("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame inline" })
vim.keymap.set("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", { desc = "Preview hunk inline" })
vim.keymap.set("n", "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", { desc = "Toggle word diff" })
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Explore" })
vim.keymap.set("n", "<leader>q", function()
	require("quicker").toggle()
end, { desc = "Quickfix list" })

vim.keymap.set("n", "<M-x>", function()
	open_command_picker()
end, { desc = "commands" })
vim.keymap.set("n", "<leader>sc", function()
	pick_colorschemes()
end, { desc = "Search colorscheme" })
vim.keymap.set("n", "<leader><space>", function()
	pick_files_fff()
end, { desc = "Find file (fff)" })
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
end, { desc = "Grep (fff)" })
vim.keymap.set("n", "<leader>sb", function()
	live_grep_current_buffer()
end, { desc = "Search buffer" })
vim.keymap.set("n", "<leader>sh", function()
	pick_help_tags()
end, { desc = "Search help" })
vim.keymap.set({ "n", "v" }, "<leader>sw", function()
	grep_string_with_fff()
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

if is_neovide then
	vim.o.guifont = "Liberation Mono:h14"
    vim.g.neovide_scale_factor = 0.9
    vim.g.neovide_refresh_rate = 165
	vim.g.neovide_opacity = 1.0
	vim.g.neovide_normal_opacity = 1.0
	vim.g.neovide_text_gamma = 1.0
	vim.g.neovide_text_contrast = 0.1
    vim.g.neovide_floating_shadow = false

	vim.keymap.set("n", "<C-=>", function()
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * 1.1
	end, { desc = "Increase Neovide scale factor" })

	vim.keymap.set("n", "<C-->", function()
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor / 1.1
	end, { desc = "Decrease Neovide scale factor" })

	if vim.g.neovide then
		local function paste_clipboard()
			-- Terminal-mode Ctrl-R is interpreted by the terminal, so use Neovim's paste API instead.
			vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
		end

		vim.keymap.set("v", "<C-S-c>", '"+y', { desc = "Copy clipboard" })
		vim.keymap.set("n", "<C-S-v>", '"+P', { desc = "Paste clipboard" })
		vim.keymap.set("v", "<C-S-v>", '"+P', { desc = "Paste clipboard" })
		vim.keymap.set("c", "<C-S-v>", "<C-R>+", { desc = "Paste clipboard" })
		vim.keymap.set({ "i", "t" }, "<C-S-v>", paste_clipboard, { desc = "Paste clipboard" })
	end
end
