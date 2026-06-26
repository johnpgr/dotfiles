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

local function copy_hl(name, src, overrides)
	local hl = vim.api.nvim_get_hl(0, { name = src, link = false })
	vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", {
		fg = hl.fg,
		bg = hl.bg,
		ctermfg = hl.ctermfg,
		ctermbg = hl.ctermbg,
		bold = hl.bold,
		italic = hl.italic,
		underline = hl.underline,
		reverse = false,
	}, overrides or {}))
end

local function link_completion_colors()
	-- Copy menu colors but never reverse; reverse on Pmenu turns kind icon fg into bg.
	copy_hl("Pmenu", "StatusLine")
	copy_hl("PmenuKind", "StatusLine")
	copy_hl("PmenuExtra", "StatusLine")
	copy_hl("PmenuMatch", "StatusLine")
	copy_hl("PmenuSbar", "StatusLine")
	copy_hl("PmenuSel", "WildMenu")
	copy_hl("PmenuKindSel", "WildMenu")
	copy_hl("PmenuExtraSel", "WildMenu")
	copy_hl("PmenuMatchSel", "WildMenu")
	copy_hl("PmenuThumb", "WildMenu")
end

local DEFAULT_CURSORLINE_BG = 6710886 -- #666666, vim's default CursorLine guibg
local FALLBACK_CURSORLINE_CTERMBG = { dark = 235, light = 252 }

local function rgb_luminance(c)
	local r = math.floor(c / 65536) % 256
	local g = math.floor(c / 256) % 256
	local b = c % 256
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function rgb_to_gray_cterm(c)
	local idx = math.floor(232 + (rgb_luminance(c) / 255) * 23 + 0.5)
	return math.max(232, math.min(255, idx))
end

local function blend_rgb(bg, fg, ratio)
	local br = math.floor(bg / 65536) % 256
	local bg_ = math.floor(bg / 256) % 256
	local bb = bg % 256
	local fr = math.floor(fg / 65536) % 256
	local fg_ = math.floor(fg / 256) % 256
	local fb = fg % 256
	local r = math.floor(br * (1 - ratio) + fr * ratio + 0.5)
	local g = math.floor(bg_ * (1 - ratio) + fg_ * ratio + 0.5)
	local b = math.floor(bb * (1 - ratio) + fb * ratio + 0.5)
	return r * 65536 + g * 256 + b
end

local function normal_cterm_base(normal_hl)
	if normal_hl.ctermbg and normal_hl.ctermbg >= 0 then
		return normal_hl.ctermbg
	end
	if normal_hl.bg then
		return rgb_to_gray_cterm(normal_hl.bg)
	end
	for _, name in ipairs({ "StatusLineNC", "TabLineFill", "NormalFloat" }) do
		local hl = vim.api.nvim_get_hl(0, { name = name })
		if hl.ctermbg and hl.ctermbg >= 0 then
			return hl.ctermbg
		end
		if hl.bg then
			return rgb_to_gray_cterm(hl.bg)
		end
	end
	return nil
end

local function apply_cursorline_highlights()
	local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
	local cursorline_hl = vim.api.nvim_get_hl(0, { name = "CursorLine" })
	local cursorline_nr_hl = vim.api.nvim_get_hl(0, { name = "CursorLineNr" })

	local bg = cursorline_hl.bg
	local ctermbg = cursorline_hl.ctermbg

	if not ctermbg or ctermbg < 0 then
		local base = normal_cterm_base(normal_hl)
		if base then
			local step = vim.o.background == "dark" and 1 or -1
			ctermbg = math.max(0, math.min(255, base + step))
		else
			ctermbg = FALLBACK_CURSORLINE_CTERMBG[vim.o.background]
				or FALLBACK_CURSORLINE_CTERMBG.dark
		end
	end

	if not bg or bg == DEFAULT_CURSORLINE_BG then
		if normal_hl.bg and normal_hl.fg then
			local ratio = vim.o.background == "dark" and 0.06 or 0.04
			bg = blend_rgb(normal_hl.bg, normal_hl.fg, ratio)
		end
	end

	local cursorline = {
		underline = false,
		cterm = { underline = false },
	}
	if bg then
		cursorline.bg = bg
	end
	if ctermbg then
		cursorline.ctermbg = ctermbg
	end

	vim.api.nvim_set_hl(0, "CursorLine", cursorline)

	local cursorline_nr = {
		underline = false,
		cterm = { underline = false },
	}
	if bg then
		cursorline_nr.bg = bg
	end
	if ctermbg then
		cursorline_nr.ctermbg = ctermbg
	end
	if cursorline_nr_hl.fg then
		cursorline_nr.fg = cursorline_nr_hl.fg
	end
	if cursorline_nr_hl.ctermfg then
		cursorline_nr.ctermfg = cursorline_nr_hl.ctermfg
	end
	if cursorline_nr_hl.bold then
		cursorline_nr.bold = cursorline_nr_hl.bold
	end

	vim.api.nvim_set_hl(0, "CursorLineNr", cursorline_nr)
	vim.api.nvim_set_hl(0, "CursorLineFold", { link = "CursorLine" })
end

local function apply_statusline_highlights(normal_hl, conceal_hl)
	local statusline_hl = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
	local fallback_ctermbg = vim.o.background == "dark" and 238 or 242
	local bg = statusline_hl.bg
		or (statusline_hl.reverse and normal_hl.fg)
		or (conceal_hl and conceal_hl.bg)
		or normal_hl.bg
	local fg = statusline_hl.fg
		or (statusline_hl.reverse and normal_hl.bg)
		or (conceal_hl and conceal_hl.fg)
		or normal_hl.fg
	local ctermbg = statusline_hl.ctermbg
		or (statusline_hl.reverse and normal_hl.ctermfg)
		or (conceal_hl and conceal_hl.ctermbg)
		or normal_cterm_base(normal_hl)
		or fallback_ctermbg
	local ctermfg = statusline_hl.ctermfg
		or (statusline_hl.reverse and normal_hl.ctermbg)
		or (conceal_hl and conceal_hl.ctermfg)
		or normal_hl.ctermfg
		or 7

	if bg and normal_hl.bg then
		bg = blend_rgb(bg, normal_hl.bg, 0.18)
	end

	if fg and conceal_hl and conceal_hl.fg then
		fg = blend_rgb(fg, conceal_hl.fg, 0.45)
	elseif fg and normal_hl.bg then
		fg = blend_rgb(fg, normal_hl.bg, 0.35)
	end

	if ctermbg then
		local step = vim.o.background == "dark" and 1 or -1
		ctermbg = math.max(0, math.min(255, ctermbg + step))
	end

	local statusline_nc = {
		fg = fg,
		bg = bg,
		ctermfg = ctermfg,
		ctermbg = ctermbg,
		reverse = false,
		bold = false,
	}

	vim.api.nvim_set_hl(0, "StatusLineNC", statusline_nc)
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
    -- vim.api.nvim_set_hl(0, "LineNr", { ctermfg = 8 })
    -- vim.api.nvim_set_hl(0, "Comment", { ctermfg = 8 })
	vim.api.nvim_set_hl(0, "Visual", { reverse = true })
	vim.api.nvim_set_hl(0, "VisualNOS", { reverse = true })
	vim.api.nvim_set_hl(0, "WinSeparator", { link = "Normal" })
	vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })
	link_completion_colors()
	-- vim.api.nvim_set_hl(0, "StatusLine", { bg = "none", fg = normal_hl.fg })
	-- vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "none", fg = normal_hl.fg })
	apply_statusline_highlights(normal_hl, conceal_hl)
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

	apply_cursorline_highlights()

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
		vim.api.nvim_set_hl(0, name, {
			sp = (hl and hl.sp) or color,
			underline = false,
			undercurl = true,
			cterm = {
				underline = false,
				undercurl = true,
			},
		})
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
