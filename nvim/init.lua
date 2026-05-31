-- Neovim configuration entry point
-- Options must be set before lazy.nvim so mapleader etc. are available
require("config.options")

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

-- Load all plugins from lua/plugins/
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

-- Load config modules (after lazy so plugins are available)
require("config.theme")
require("config.statusline")
require("config.cmdline")
require("config.lsp")
require("config.autocmds")
require("config.picker")
require("config.keymaps")
