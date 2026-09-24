local ui2 = require("vim._core.ui2")
local cmd = vim.api.nvim_create_user_command
local autocmd = vim.api.nvim_create_autocmd
local map = vim.keymap.set

local function has_executable(name)
	return vim.fn.executable(name) == 1
end

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_nvim_dir_plugin = 1
vim.g.mapleader = " "

vim.o.confirm = true
vim.o.termguicolors = false
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.autocomplete = true
vim.o.complete = ".^5,w^5,b^5,u^5"
vim.o.completeopt = "menu,popup"
vim.o.syntax = "off"
vim.o.signcolumn = "no"
vim.o.exrc = true
vim.o.secure = true
vim.o.undofile = true
vim.o.swapfile = false
vim.o.updatetime = 200
vim.o.autoindent = true
vim.o.smartindent = true
vim.o.smartcase = true
vim.o.ignorecase = true
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.wrap = false

vim.opt.diffopt:append("linematch:60")

if #vim.api.nvim_list_uis() > 0 then
	ui2.enable()
else
	autocmd("UIEnter", {
		once = true,
		callback = function()
			ui2.enable()
		end,
	})
end

if vim.g.clipboard == nil then
	local is_windows_or_wsl = vim.fn.has("win32") == 1 or vim.env.WSL_DISTRO_NAME ~= nil
	if is_windows_or_wsl and (has_executable("win32yank.exe") or has_executable("win32yank")) then
		vim.g.clipboard = "win32yank"
	end
end
vim.opt.clipboard = "unnamedplus"

vim.pack.add({
	"https://github.com/chomosuke/typst-preview.nvim",
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/tpope/vim-abolish",
	"https://github.com/farmergreg/vim-lastplace",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/johmsalas/text-case.nvim",
	"https://github.com/Axlefublr/selabel.nvim",
	"https://github.com/ChmaraX/herdr-nvim",
	"https://github.com/stevearc/quicker.nvim",
	"https://github.com/sindrets/diffview.nvim",
})

require("diffview").setup({
	use_icons = false,
	view = {
		merge_tool = {
			layout = "diff3_mixed",
			disable_diagnostics = true,
			winbar_info = true,
		},
	},
})

map("n", "<leader>gD", ":DiffviewOpen ", { desc = "Git DiffView" })
map("n", "<leader>gh", function()
	vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
end, { desc = "Git file history (Current)" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Git file history (All)" })

require("herdr-nvim").setup({})
require("textcase").setup()
require("selabel-config").setup({})
require("quicker").setup({
	keys = {
		{
			">",
			function()
				require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
			end,
			desc = "Expand quickfix context",
		},
		{
			"<",
			function()
				require("quicker").collapse()
			end,
			desc = "Collapse quickfix context",
		},
	},
})

local function pick_case()
	vim.ui.select({
		{ label = "camelCase", key = "c", method = "to_camel_case" },
		{ label = "PascalCase", key = "p", method = "to_pascal_case" },
		{ label = "snake_case", key = "s", method = "to_snake_case" },
		{ label = "dash-case", key = "d", method = "to_dash_case" },
		{ label = "CONSTANT_CASE", key = "n", method = "to_constant_case" },
		{ label = "UPPER CASE", key = "u", method = "to_upper_case" },
		{ label = "lower case", key = "l", method = "to_lower_case" },
		{ label = "Title Case", key = "t", method = "to_title_case" },
		{ label = "dot.case", key = ".", method = "to_dot_case" },
		{ label = "Title-Dash Case", key = "T", method = "to_title_dash_case" },
		{ label = "Phrase case", key = "P", method = "to_phrase_case" },
	}, {
		prompt = "Text case",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice then
			require("textcase").quick_replace(choice.method)
		end
	end)
end

map({ "n", "x" }, "tc", pick_case, { desc = "Text case conversion" })

require("which-key").setup({
	preset = "helix",
	icons = vim.g.icons_enabled and { mappings = false } or {
		breadcrumb = "",
		separator = "->",
		group = "",
		ellipsis = "...",
		mappings = false,
		rules = false,
		colors = false,
		keys = {
			Up = "Up ",
			Down = "Down ",
			Left = "Left ",
			Right = "Right ",
			C = "C-",
			M = "M-",
			D = "D-",
			S = "S-",
			CR = "CR ",
			Esc = "Esc ",
			ScrollWheelDown = "ScrollWD ",
			ScrollWheelUp = "ScrollWU ",
			NL = "NL ",
			BS = "BS ",
			Space = "SPC ",
			Tab = "Tab ",
			F1 = "F1",
			F2 = "F2",
			F3 = "F3",
			F4 = "F4",
			F5 = "F5",
			F6 = "F6",
			F7 = "F7",
			F8 = "F8",
			F9 = "F9",
			F10 = "F10",
			F11 = "F11",
			F12 = "F12",
		},
	},
	win = {
		border = "single",
		height = { min = 4, max = math.huge },
	},
})

require("gitsigns").setup({
	attach_to_untracked = true,
	preview_config = {
		border = "single",
		focusable = false,
	},
})

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

map("n", "]h", function()
	nav_hunk("next")
end, { desc = "Next hunk" })
map("n", "[h", function()
	nav_hunk("prev")
end, { desc = "Previous hunk" })
map("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
map("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
map("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })
map("n", "<leader>gB", "<cmd>Gitsigns blame<cr>", { desc = "Git blame" })
map("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame inline" })
map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
map("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", { desc = "Preview hunk inline" })
map("n", "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", { desc = "Toggle word diff" })

vim.keymap.set("n", "<leader>tu", function()
	vim.cmd.packadd("nvim.undotree")
	vim.cmd.Undotree()
end, { desc = "Undotree" })

cmd("Tex", function()
	vim.cmd("new | terminal")
end, { desc = "Open a terminal in a horizontal split" })

cmd("Vtex", function()
	vim.cmd("vnew | terminal")
end, { desc = "Open a terminal in a vertical split" })

local herdr_nav = require("herdr")
map("n", "<C-h>", function()
	herdr_nav.navigate("h")
end, { desc = "Focus split left" })
map("n", "<C-j>", function()
	herdr_nav.navigate("j")
end, { desc = "Focus split down" })
map("n", "<C-k>", function()
	herdr_nav.navigate("k")
end, { desc = "Focus split up" })
map("n", "<C-l>", function()
	herdr_nav.navigate("l")
end, { desc = "Focus split right" })
map("n", "<M-h>", function()
	herdr_nav.resize("h")
end, { desc = "Resize split left" })
map("n", "<M-j>", function()
	herdr_nav.resize("j")
end, { desc = "Resize split down" })
map("n", "<M-k>", function()
	herdr_nav.resize("k")
end, { desc = "Resize split up" })
map("n", "<M-l>", function()
	herdr_nav.resize("l")
end, { desc = "Resize split right" })

map("n", "<C-p>", "<C-w>p", { desc = "Focus previous window" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
map("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
map("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear Highlights" })
map("n", "<leader>re", "<cmd>restart<cr>", { desc = "Restart" })
map("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
map("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "yig", ":%y<CR>", { desc = "Yank buffer" })
map("n", "vig", "ggVG", { desc = "Visual select buffer" })
map("n", "cig", ":%d<CR>i", { desc = "Change buffer" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
map("v", "<", "<gv", { desc = "Decrease indent" })
map("v", ">", ">gv", { desc = "Increase indent" })

map("n", "<leader>m", "<cmd>Compile<cr>", { desc = "Compile something" })

for name, split_command in pairs({
	Explore = "edit",
	Sexplore = "split",
	Vexplore = "vsplit",
}) do
	cmd(name, function(opts)
		vim.api.nvim_cmd({ cmd = split_command, args = { opts.args ~= "" and opts.args or "." } }, {})
	end, { nargs = "?", complete = "dir", desc = "Open a directory with Oil" })
end

autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.hl.hl_op()
	end,
})

require("compile")
require("mini")
require("fff-nvim")
require("neogit-config")
require("oil-config")
require("typst-preview").setup({})

vim.treesitter.start = function() end
vim.cmd.syntax("off")
