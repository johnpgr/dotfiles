vim.treesitter.start()
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.tabstop = 2
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
vim.opt_local.indentkeys:append({ "=end", "=else", "=elsif", "=when", "=in", "=ensure", "=rescue" })

local root

local function crystal_stdlib()
	if root then
		return root
	end

	local crystal = vim.fn.exepath("crystal")
	if crystal == "" then
		vim.notify("Crystal is not on PATH", vim.log.levels.WARN)
		return
	end

	local result = vim.system({ crystal, "env", "CRYSTAL_PATH" }, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify(vim.trim(result.stderr or "Could not read CRYSTAL_PATH"), vim.log.levels.WARN)
		return
	end

	local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
	local paths = vim.split(vim.trim(result.stdout), separator, { trimempty = true })
	for i = #paths, 1, -1 do
		local path = paths[i]
		if vim.uv.fs_stat(vim.fs.joinpath(path, "prelude.cr")) then
			root = vim.fs.normalize(path)
			return root
		end
	end

	vim.notify("Could not find Crystal's stdlib in CRYSTAL_PATH", vim.log.levels.WARN)
end

local function with_stdlib(callback)
	local path = crystal_stdlib()
	if path then
		callback(path)
	end
end

local opts = { buffer = true }

vim.keymap.set("n", "<leader>fC", function()
	with_stdlib(function(path)
		require("fff").find_files({ cwd = path, resume = true, resume_key = "crystal-stdlib" })
	end)
end, vim.tbl_extend("force", opts, { desc = "Find Crystal stdlib files" }))

vim.keymap.set("n", "<leader>sC", function()
	with_stdlib(function(path)
		require("fff").live_grep({ cwd = path, resume = true, resume_key = "crystal-stdlib-grep" })
	end)
end, vim.tbl_extend("force", opts, { desc = "Search Crystal stdlib" }))

vim.keymap.set("n", "<leader>oC", function()
	with_stdlib(function(path)
		require("oil").open(path)
	end)
end, vim.tbl_extend("force", opts, { desc = "Browse Crystal stdlib with Oil" }))

vim.keymap.set(
	"x",
	"<leader>!",
	":!crystal tool format - ",
	vim.tbl_extend("force", opts, { desc = "Filter selection through crystal tool format" })
)
