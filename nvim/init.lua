-- Neovim configuration entry point
require("config.options")

-- fff initialized lazily by config.find + config.grep on first use.
local function fff_base_path()
	local cwd = vim.fn.getcwd()
	local home = (vim.uv or vim.loop).os_homedir()
	if not home then
		return cwd
	end

	local real_cwd = (vim.uv or vim.loop).fs_realpath(cwd) or vim.fn.fnamemodify(cwd, ":p"):gsub("/+$", "")
	local real_home = (vim.uv or vim.loop).fs_realpath(home) or vim.fn.fnamemodify(home, ":p"):gsub("/+$", "")
	return real_cwd == real_home and vim.fn.stdpath("config") or cwd
end

vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, {
	base_path = fff_base_path(),
	lazy_sync = true,
})

-- Plugins are loaded via plugin/ files (auto-sourced by Neovim after init.lua).
-- Config modules that depend on plugins are loaded from plugin/zz-config.lua.
