local fff_config = require("config.fff")
local language_sources = require("config.language_sources")

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

vim.api.nvim_create_autocmd("PackChanged", {
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

vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, {
	base_path = fff_config.base_path(),
	lazy_sync = true,
	prompt = "",
	title = "Find Files",
	layout = { prompt_position = "top" },
	hl = { cursor = "CursorLine" },
	-- debug = { enabled = true, show_scores = true },
})

local function sync_base_path()
	vim.g.fff = vim.tbl_deep_extend("force", vim.g.fff or {}, { base_path = fff_config.base_path() })
end

vim.api.nvim_create_autocmd("DirChanged", {
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

vim.keymap.set("n", "<leader>ff", function()
	require("fff").find_files({ cwd = fff_config.base_path() })
end, { desc = "Find" })

vim.keymap.set("n", "<leader>fn", function()
	require("fff").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find in Neovim config" })

vim.keymap.set("n", "<leader>fp", function()
	require("fff").find_files({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack") })
end, { desc = "Find in vim.pack plugins" })

vim.keymap.set("n", "<leader>fs", function()
	local language = language_sources.name_for(vim.bo.filetype)
	local path = language_sources.current()
	if path then
		require("fff").find_files({ cwd = path, title = language .. " stdlib files" })
	end
end, { desc = "Find in language stdlib" })

vim.keymap.set("n", "<leader>sn", function()
	require("fff").live_grep({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search in Neovim config" })

vim.keymap.set("n", "<leader>sp", function()
	require("fff").live_grep({ cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack") })
end, { desc = "Search in vim.pack plugins" })

vim.keymap.set("n", "<leader>ss", function()
	local language = language_sources.name_for(vim.bo.filetype)
	local path = language_sources.current()
	if path then
		require("fff").live_grep({ cwd = path, title = language .. " stdlib search" })
	end
end, { desc = "Search in language stdlib" })

vim.keymap.set("n", "<leader>sd", function()
	require("fff").live_grep({
		cwd = fff_config.base_path(),
		grep = { modes = { "plain", "fuzzy" } },
	})
end, { desc = "Search directory" })

vim.keymap.set({ "n", "x" }, "<leader>sw", function()
	require("fff").live_grep({ cwd = fff_config.base_path(), query = cword_or_selection() })
end, { desc = "Search current word / selection" })
