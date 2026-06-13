-- Theme: colorscheme overrides, dark/light sync, and persistence

local theme_uv = vim.uv or vim.loop
local colorscheme_file = vim.fn.stdpath("config") .. "/.colorscheme"
local theme_state_file = vim.fs.joinpath(vim.loop.os_homedir(), ".dotfiles", ".theme_state")
local theme_state_dir = vim.fs.dirname(theme_state_file)
local theme_state_name = vim.fs.basename(theme_state_file)

local theme_state_watcher
local theme_state_timer
local last_applied_mode
local theme_apply_in_progress = false
local theme_sync_pending = false
local apply_theme_state
local sync_theme_state

-- --------------------------------------------------------------------------
-- Colorscheme highlight overrides
-- --------------------------------------------------------------------------

local function link_completion_colors()
	local links = {
		Pmenu = "StatusLine",
		PmenuKind = "StatusLine",
		PmenuExtra = "StatusLine",
		PmenuMatch = "StatusLine",
		PmenuSbar = "StatusLine",
		PmenuSel = "WildMenu",
		PmenuKindSel = "WildMenu",
		PmenuExtraSel = "WildMenu",
		PmenuMatchSel = "WildMenu",
		PmenuThumb = "WildMenu",
	}

	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target })
	end
end

local function apply_colorscheme_overrides()
	local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
	local conceal_hl = vim.api.nvim_get_hl(0, { name = "Conceal" })
	local hint_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticHint" })
	local warn_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn" })
	local err_hl = vim.api.nvim_get_hl(0, { name = "DiagnosticError" })
	-- local matchparen_hl = vim.api.nvim_get_hl(0, { name = "MatchParen" })
	local muted_color = (conceal_hl and conceal_hl.fg)
	-- local accent_color = (hint_hl and hint_hl.fg) or (warn_hl and warn_hl.fg) or muted_color

	-- vim.api.nvim_set_hl(
	-- 	0,
	-- 	"MatchParen",
	-- 	vim.tbl_extend("force", matchparen_hl or {}, {
	-- 		fg = (err_hl and err_hl.fg) or accent_color,
	-- 		underline = false,
	-- 		undercurl = false,
	-- 		underdouble = false,
	-- 		underdotted = false,
	-- 		underdashed = false,
	-- 	})
	-- )

	-- Some manual fixing of color tokens
    vim.api.nvim_set_hl(0, "LineNr", { ctermfg = 8 })
    vim.api.nvim_set_hl(0, "Comment", { ctermfg = 8 })
	vim.api.nvim_set_hl(0, "Visual", { reverse = true })
	vim.api.nvim_set_hl(0, "VisualNOS", { reverse = true })
	vim.api.nvim_set_hl(0, "CursorLineFold", { link = "CursorLine" })
	vim.api.nvim_set_hl(0, "WinSeparator", { link = "Normal" })
	vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
	link_completion_colors()
	vim.api.nvim_set_hl(0, "CompletionGhost", { fg = muted_color, ctermfg = 8, bg = "none" })
	vim.api.nvim_set_hl(0, "StatusLine", { bg = "none", fg = normal_hl.fg })
	vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "none", fg = normal_hl.fg })
	vim.api.nvim_set_hl(0, "@function.call", { link = "@function" })
	vim.api.nvim_set_hl(0, "@function.method", { link = "@function" })
	vim.api.nvim_set_hl(0, "@function.builtin", { link = "@function" })
	vim.api.nvim_set_hl(0, "@keyword.function", { link = "@keyword" })
	vim.api.nvim_set_hl(0, "@type.builtin.odin", { link = "Type" })
	vim.api.nvim_set_hl(0, "@constant.builtin.odin", { link = "Type" })
	vim.api.nvim_set_hl(0, "@module.odin", { link = "@variable.odin" })
	vim.api.nvim_set_hl(0, "@tag.builtin", { link = "@type.builtin" })
	vim.api.nvim_set_hl(0, "NeoTreeNormal", { link = "Normal" })
	vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { link = "Normal" })
	if vim.g.colors_name == "quiet" then
		vim.api.nvim_set_hl(0, "TabLineSel", { link = "Normal" })
	end

	if vim.g.colors_name == "photon" then
		vim.api.nvim_set_hl(0, "Statement", { link = "Constant" })
	end

	-- Making treesitter usable
	for _, group in ipairs({
		"@number",
		"@operator",
		"@constant",
		"@punctuation.bracket",
		"@punctuation.delimiter",
		"@variable",
		"@variable.parameter",
		"@property",
		"@constructor",
		"@variable.member",
		"Special",
		"SpecialChar",
		"@tag.attribute",
	}) do
		vim.api.nvim_set_hl(0, group, { fg = normal_hl.fg })
	end

	for _, group in ipairs({
		"LspReferenceText",
		"LspReferenceRead",
		"LspReferenceWrite",
	}) do
		vim.api.nvim_set_hl(0, group, {
			sp = muted_color,
			underline = true,
		})
	end

	if vim.g.colors_name == "embark" then
		vim.api.nvim_set_hl(0, "Normal", { bg = "#0f1519" })
		vim.api.nvim_set_hl(0, "WinSeparator", { link = "NeoTreeIndentMarker" })
		vim.api.nvim_set_hl(0, "Directory", { fg = "#8faabc" })
	end

	-- Customize diagnostic underlines to use undercurl
	local diagnostic_colors = {
		Error = err_hl and err_hl.fg,
		Warn = warn_hl and warn_hl.fg,
		Info = (conceal_hl and conceal_hl.fg) or (hint_hl and hint_hl.fg),
		Hint = hint_hl and hint_hl.fg,
	}

	for _, diag in ipairs({ "Error", "Warn", "Info", "Hint" }) do
		local name = "DiagnosticUnderline" .. diag
		local hl = vim.api.nvim_get_hl(0, { name = name })
		local color = diagnostic_colors[diag]
		vim.api.nvim_set_hl(
			0,
			name,
			vim.tbl_extend("force", hl or {}, {
				underline = false,
				undercurl = true,
				sp = hl.sp or color,
			})
		)
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = apply_colorscheme_overrides,
})

-- --------------------------------------------------------------------------
-- Theme state (dark / light) watcher
-- --------------------------------------------------------------------------

local function close_handle(handle)
	if handle and not handle:is_closing() then
		handle:close()
	end
end

local function read_theme_state()
	local f = io.open(theme_state_file, "r")
	if not f then
		return nil
	end

	local mode = f:read("*all")
	f:close()

	mode = mode and vim.trim(mode) or ""
	if mode == "dark" or mode == "light" then
		return mode
	end

	return nil
end

local initial_theme_state = read_theme_state()
if initial_theme_state then
	vim.o.background = initial_theme_state
	last_applied_mode = initial_theme_state
end

local function current_colorscheme()
	local colors_name = vim.g.colors_name
	if type(colors_name) == "string" and colors_name ~= "" then
		return colors_name
	end

	return nil
end

local function apply_theme_state_now(mode, opts)
	opts = opts or {}
	if mode ~= "dark" and mode ~= "light" then
		return false
	end

	if theme_apply_in_progress then
		theme_sync_pending = true
		return false
	end

	if mode == last_applied_mode and not opts.force then
		return false
	end

	theme_apply_in_progress = true

	local ok, err = pcall(function()
		vim.o.background = mode

		if opts.reapply_colorscheme ~= false then
			local colors_name = current_colorscheme()
			if colors_name then
				vim.cmd.colorscheme(colors_name)
			end
		end
	end)

	theme_apply_in_progress = false

	if ok then
		last_applied_mode = mode
	else
		vim.notify("Unable to apply theme state: " .. err, vim.log.levels.WARN)
	end

	if theme_sync_pending then
		theme_sync_pending = false
		vim.schedule(function()
			sync_theme_state({ force = true })
		end)
	end

	return ok
end

sync_theme_state = function(opts)
	return apply_theme_state(read_theme_state(), opts)
end

local function debounce_theme_sync()
	if not theme_uv or not theme_uv.new_timer then
		sync_theme_state()
		return
	end

	if theme_state_timer and theme_state_timer:is_closing() then
		theme_state_timer = nil
	end

	if not theme_state_timer then
		theme_state_timer = theme_uv.new_timer()
	end

	if not theme_state_timer then
		sync_theme_state()
		return
	end

	theme_state_timer:stop()
	theme_state_timer:start(
		100,
		0,
		vim.schedule_wrap(function()
			sync_theme_state()
		end)
	)
end

apply_theme_state = function(mode, opts)
	if mode ~= "dark" and mode ~= "light" then
		return false
	end

	if vim.in_fast_event() then
		vim.schedule(function()
			apply_theme_state_now(mode, opts)
		end)
		return true
	end

	return apply_theme_state_now(mode, opts)
end

local function start_theme_state_watcher()
	if theme_state_watcher or not theme_uv or not theme_uv.new_fs_event then
		return false
	end

	theme_state_watcher = theme_uv.new_fs_event()
	if not theme_state_watcher then
		return false
	end

	local ok, err = theme_state_watcher:start(theme_state_dir, {}, function(watch_err, filename)
		if watch_err then
			vim.schedule(function()
				vim.notify("Theme watcher error: " .. watch_err, vim.log.levels.WARN)
			end)
			return
		end

		if filename and filename ~= theme_state_name then
			return
		end

		debounce_theme_sync()
	end)

	if not ok then
		close_handle(theme_state_watcher)
		theme_state_watcher = nil
		vim.notify("Unable to start theme watcher: " .. err, vim.log.levels.WARN)
		return false
	end

	return true
end

local function stop_theme_state_watcher()
	if theme_state_timer then
		theme_state_timer:stop()
		close_handle(theme_state_timer)
		theme_state_timer = nil
	end

	if theme_state_watcher then
		theme_state_watcher:stop()
		close_handle(theme_state_watcher)
		theme_state_watcher = nil
	end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		stop_theme_state_watcher()
	end,
})

-- --------------------------------------------------------------------------
-- Colorscheme persistence
-- --------------------------------------------------------------------------

local function persist_colorscheme(colors_name)
	if type(colors_name) == "table" then
		colors_name = colors_name.text
	end

	if type(colors_name) ~= "string" or colors_name == "" then
		vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
		return
	end

	local f = io.open(colorscheme_file, "w")
	if not f then
		vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
		return
	end

	f:write(colors_name)
	f:close()
end

local function load_persisted_colorscheme()
	local f = io.open(colorscheme_file, "r")
	if f then
		local persisted = f:read("*all")
		f:close()

		persisted = persisted and vim.trim(persisted) or ""
		if persisted ~= "" then
			local ok, err = pcall(vim.cmd.colorscheme, persisted)
			if ok then
				vim.api.nvim_exec_autocmds("ColorScheme", { pattern = persisted })
			else
				vim.notify(
					string.format("Unable to load persisted colorscheme '%s': %s", persisted, err),
					vim.log.levels.WARN
				)
			end
		end
	end

	sync_theme_state({ force = true })
end

-- --------------------------------------------------------------------------
-- Public API
-- --------------------------------------------------------------------------

load_persisted_colorscheme()
start_theme_state_watcher()

return {
	persist_colorscheme = persist_colorscheme,
}
