local map = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd

local function base_path()
	local cwd = vim.fn.getcwd()
	local home = (vim.uv or vim.loop).os_homedir()
	if not home then
		return cwd
	end

	local real_cwd = (vim.uv or vim.loop).fs_realpath(cwd) or vim.fn.fnamemodify(cwd, ":p"):gsub("/+$", "")
	local real_home = (vim.uv or vim.loop).fs_realpath(home) or vim.fn.fnamemodify(home, ":p"):gsub("/+$", "")
	return real_cwd == real_home and vim.fn.stdpath("config") or cwd
end

vim.pack.add({
	{ src = "https://github.com/dmtrKovalenko/fff.nvim", version = vim.version.range("0.9") },
})

if not vim.g.icons_enabled then
	package.preload["fff.file_picker.icons"] = function()
		return {
			setup = function()
				return false
			end,
			get_icon = function()
				return nil, nil
			end,
			get_directory_icon = function()
				return nil, nil
			end,
			supports_directories = function()
				return false
			end,
			get_provider_info = function()
				return { name = "disabled", available = false, supports_directories = false }
			end,
		}
	end
end

autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "fff.nvim" and (kind == "install" or kind == "update") then
			if not ev.data.active then
				vim.cmd.packadd("fff.nvim")
			end
			require("fff.download").download_or_build_binary()
		end
	end,
})

local fff_download = require("fff.download")
if not vim.uv.fs_stat(fff_download.get_binary_path()) then
	local ok, err = pcall(fff_download.download_or_build_binary)
	if not ok then
		vim.schedule(function()
			vim.notify("fff.nvim binary setup failed: " .. tostring(err), vim.log.levels.ERROR)
		end)
	end
end

vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, {
	base_path = base_path(),
	lazy_sync = true,
	prompt = "",
	title = "Find Files",
	layout = { prompt_position = "top" },
	hl = { cursor = "CursorLine" },
	debug = { enabled = vim.g.icons_enabled, show_scores = vim.g.icons_enabled },
})

local function sync_base_path()
	vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, { base_path = base_path() })
end

autocmd("DirChanged", {
	group = vim.api.nvim_create_augroup("FffRootSync", {}),
	callback = function()
		if vim.v.event.scope == "window" then
			return
		end
		sync_base_path()
	end,
})

local function cword_or_selection()
	local mode = vim.fn.mode()
	if mode:match("^[vV\22]") then
		local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
		return lines[1] or ""
	end
	return vim.fn.expand("<cword>")
end

map("n", "<leader>ff", function()
	require("fff").find_files({ cwd = base_path() })
end, { desc = "Find" })

map("n", "<leader>fn", function()
	require("fff").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find in Neovim config" })

map("n", "<leader>fp", function()
	require("fff").find_files({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack") })
end, { desc = "Find in vim.pack plugins" })


map("n", "<leader>sn", function()
	require("fff").live_grep({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search in Neovim config" })

map("n", "<leader>sp", function()
	require("fff").live_grep({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack") })
end, { desc = "Search in vim.pack plugins" })

map("n", "<leader>sd", function()
	require("fff").live_grep({
		cwd = base_path(),
		grep = { modes = { "plain", "fuzzy" } },
	})
end, { desc = "Search directory" })

map({ "n", "x" }, "<leader>sw", function()
	require("fff").live_grep({ cwd = base_path(), query = cword_or_selection() })
end, { desc = "Search current word / selection" })
