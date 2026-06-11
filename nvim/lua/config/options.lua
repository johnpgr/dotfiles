-- Global flags
vim.g.emacs_tab = true
vim.g.treesitter_enabled = false
vim.g.icons_enabled = false
vim.g.mapleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Editor options
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
vim.o.breakindent = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.termguicolors = false
vim.o.updatetime = 200
vim.o.undofile = true
vim.o.exrc = true
vim.o.secure = true
vim.o.cmdheight = 1
vim.o.laststatus = 3
vim.o.spelllang = "en,pt_br"
vim.opt.clipboard = "unnamedplus"
vim.opt.diffopt:append("linematch:60")
vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:,vert:│,horiz:─,horizup:─,horizdown:─]]

require("vim._core.ui2").enable({})

-- macOS: ensure SDKROOT is set for clangd / xcrun tools
if vim.fn.has("mac") == 1 and not vim.env.SDKROOT and vim.fn.executable("xcrun") == 1 then
	local sdkroot = vim.trim(vim.fn.system("xcrun --show-sdk-path"))
	if vim.v.shell_error == 0 and sdkroot ~= "" then
		vim.env.SDKROOT = sdkroot
	end
end

-- Windows: prefer bash; fall back to pwsh
if vim.fn.has("win32") == 1 then
	if vim.fn.executable("bash") == 1 then
		vim.opt.shell = "bash"
		vim.opt.shellcmdflag = "-c"
        vim.opt.shellquote = ""
		vim.opt.shellxquote = ""
		vim.opt.shellpipe = "2>&1 | tee"
		vim.opt.shellredir = ">%s 2>&1"
	else
		vim.opt.shell = "pwsh"
	end
end
