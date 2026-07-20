-- Global flags
vim.g.icons_enabled = false
vim.g.emacs_tab = false
vim.g.treesitter_enabled = true
vim.g.mapleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.o.background = "dark"

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
vim.o.foldcolumn = "0"
vim.o.breakindent = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.termguicolors = true
vim.o.updatetime = 200
vim.o.undofile = true
vim.o.exrc = true
vim.o.secure = true
vim.o.cmdheight = 1
vim.o.laststatus = 2
vim.o.spelllang = "en,pt_br"
require("config.clipboard").setup()
require("config.theme").setup()
require("syntax").setup()
vim.opt.diffopt:append("linematch:60")

require("vim._core.ui2").enable({})

if vim.g.neovide then
	vim.o.guifont = "IosevkaInput:h12"
	vim.g.neovide_refresh_rate = 165
	vim.g.neovide_opacity = 1.0
	vim.g.neovide_floating_shadow = false
end
