require("options")
require("statusline")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Load lazy.nvim with plugins
require("lazy").setup("plugins", {
	ui = {
		border = "single",
	},
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})

-- Filetype additions
vim.filetype.add({
	extension = {
		hlsl = "hlsl",
		m = "objc",
	},
})

-- Only on nightly
if vim.version().minor >= 12 then
	require("vim._extui").enable({})
end

require("autocmds")
require("keymaps")

if require("utils").is_neovide then
	require("neovide")
end

vim.cmd([[
    hi! link MsgSeparator WinSeparator
    hi! link PmenuExtra Pmenu
    hi Operator guibg=none
    hi MatchParen guifg=bg
    hi WinBar guibg=none
    hi WinBarNC guibg=none
    hi NormalFloat guibg=none
    hi FloatBorder guibg=none
    hi TelescopeBorder guibg=none
    hi WhichKeyBorder guibg=none
    hi FoldColumn ctermbg=none guibg=none
]])
