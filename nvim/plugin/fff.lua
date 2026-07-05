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

vim.pack.add({ "https://github.com/dmtrKovalenko/fff.nvim" })

if not vim.uv.fs_stat(require("fff.download").get_binary_path()) then
	require("fff.download").download_or_build_binary()
end
