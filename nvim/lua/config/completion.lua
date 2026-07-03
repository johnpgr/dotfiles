-- Completion: mini.completion (LSP popup menu with auto-open delay)

local M = {}

-- Delay (ms) before the completion popup auto-opens while typing.
local COMPLETION_DELAY_MS = 0
-- Max visible rows in the completion popup.
local PUM_MAX_HEIGHT = 20
-- Max width in characters; keeps the info window beside the menu.
local PUM_MAX_WIDTH = 60
-- Open immediately after these characters (member access, etc.), like VS Code.
local SCOPED_TRIGGER_CHARS = {
	["."] = true,
	[":"] = true,
}

-- Built lazily on first use; avoids work at module-load time.
local kind_name_by_id

-- Caches: icon/hl per kind-id (hot path) and derived hlgroup per source-hl.
local kind_icon_cache = {} -- [kind_id] = { icon, hl }
local kind_hl_cache = {} -- [mini_icons_hl] = derived_hlgroup_name

local function reset_caches()
	kind_icon_cache = {}
	kind_hl_cache = {}
end

local function resolve_hl_attrs(hl_name)
	-- link=false already resolves the chain; no recursion needed.
	return vim.api.nvim_get_hl(0, { name = hl_name, link = false })
end

local function rgb_luminance(c)
	if not c then
		return nil
	end
	local r = math.floor(c / 65536) % 256
	local g = math.floor(c / 256) % 256
	local b = c % 256
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function contrast_ratio(fg, bg)
	local fg_lum = rgb_luminance(fg)
	local bg_lum = rgb_luminance(bg)
	if not fg_lum or not bg_lum then
		return nil
	end
	local lighter = math.max(fg_lum, bg_lum)
	local darker = math.min(fg_lum, bg_lum)
	return (lighter + 0.05) / (darker + 0.05)
end

local function scale_rgb(fg, factor)
	local r = math.floor(fg / 65536) % 256
	local g = math.floor(fg / 256) % 256
	local b = fg % 256
	return math.floor(r * factor + 0.5) * 65536 + math.floor(g * factor + 0.5) * 256 + math.floor(b * factor + 0.5)
end

local function effective_popup_bg()
	local pum = resolve_hl_attrs("Pmenu")
	if pum.bg then
		return pum.bg
	end
	return resolve_hl_attrs("Normal").bg
end

-- Light themes often map icon groups to pale Diagnostic* colors that match the
-- popup background (especially when Pmenu bg is inherited/transparent).
local function ensure_popup_icon_fg(fg, ctermfg, mini_icons_hl)
	local normal = resolve_hl_attrs("Normal")
	local popup_bg = effective_popup_bg()
	local fallback_fg = normal.fg
	local fallback_ctermfg = normal.ctermfg or ctermfg

	if not fg then
		return fallback_fg, fallback_ctermfg
	end

	if vim.o.background ~= "light" then
		return fg, ctermfg
	end

	-- The terminal config uses cterm colors (`termguicolors=false`), so GUI-only
	-- contrast fixes do not affect the actual popup. Use a visible per-kind
	-- palette instead of inheriting pale Diagnostic* colors from light themes.
	ctermfg = ({
		MiniIconsAzure = 33,
		MiniIconsBlue = 27,
		MiniIconsCyan = 37,
		MiniIconsGreen = 34,
		MiniIconsGrey = 242,
		MiniIconsOrange = 166,
		MiniIconsPurple = 129,
		MiniIconsRed = 160,
		MiniIconsYellow = 136,
	})[mini_icons_hl] or ctermfg

	local min_ratio = 2.8
	local fg_lum = rgb_luminance(fg)
	local max_lum = 130
	if fg_lum and fg_lum > max_lum then
		fg = scale_rgb(fg, max_lum / fg_lum)
		fg_lum = rgb_luminance(fg)
	end

	if popup_bg then
		for _ = 1, 8 do
			if contrast_ratio(fg, popup_bg) >= min_ratio then
				break
			end
			fg = scale_rgb(fg, 0.82)
		end
	end

	local ratio = popup_bg and contrast_ratio(fg, popup_bg)
	if ratio and ratio < min_ratio then
		fg = fallback_fg or fg
	end

	-- MiniIconsGrey has no linked fg; use a mid grey on light backgrounds.
	if mini_icons_hl == "MiniIconsGrey" and (not fg or rgb_luminance(fg) > max_lum) then
		fg = scale_rgb(0x808080, 0.75)
	end

	return fg, ctermfg
end

local function ensure_kind_names()
	if kind_name_by_id then
		return
	end
	kind_name_by_id = {}
	for name, id in pairs(vim.lsp.protocol.CompletionItemKind) do
		if type(name) == "string" and type(id) == "number" then
			kind_name_by_id[id] = name
		end
	end
end

local function kind_icon_hlgroup(mini_icons_hl)
	local cached = kind_hl_cache[mini_icons_hl]
	if cached then
		return cached
	end

	local src = resolve_hl_attrs(mini_icons_hl)
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	local fg = src.fg or normal.fg
	local ctermfg = src.ctermfg or normal.ctermfg
	fg, ctermfg = ensure_popup_icon_fg(fg, ctermfg, mini_icons_hl)

	local dst_hl = "DotfilesPmenuKindIcon_" .. mini_icons_hl

	vim.api.nvim_set_hl(0, dst_hl, {
		fg = fg,
		ctermfg = ctermfg,
		bg = "NONE",
		ctermbg = "NONE",
		reverse = false,
		force = true,
	})

	kind_hl_cache[mini_icons_hl] = dst_hl
	return dst_hl
end

local function hide_kind_column()
	for i = 1, #vim.lsp.protocol.CompletionItemKind do
		vim.lsp.protocol.CompletionItemKind[i] = ""
	end
end

--- Resolve icon + hl for a CompletionItemKind id, cached per kind.
local function get_kind_icon_hl(kind_id)
	local cached = kind_icon_cache[kind_id]
	if cached then
		return cached[1], cached[2]
	end
	ensure_kind_names()
	local kind_name = kind_name_by_id[kind_id] or "Unknown"
	local icon, hl = MiniIcons.get("lsp", kind_name)
	kind_icon_cache[kind_id] = { icon, hl }
	return icon, hl
end

local function colorize_by_kind(items)
	if _G.MiniIcons == nil then
		return items
	end

	for _, item in ipairs(items) do
		local icon, hl = get_kind_icon_hl(item.kind)
		local name = item.label
		local details = item.labelDetails or {}
		local signature = details.detail
		local description = details.description

		item.dotfiles_icon = icon
		item.labelDetails = {
			detail = signature and signature ~= "" and (name .. " " .. signature) or name,
			description = description,
		}

		if item.abbr_hlgroup ~= "MiniCompletionDeprecated" then
			item.abbr_hlgroup = kind_icon_hlgroup(hl)
		end
		item.kind_hlgroup = nil
	end

	return items
end

local function process_items(items, base)
	items = MiniCompletion.default_process_items(items, base)
	return colorize_by_kind(items)
end

local function get_mini_completion_h()
	for i = 1, math.huge do
		local name, value = debug.getupvalue(MiniCompletion.completefunc_lsp, i)
		if name == nil then
			return
		end
		if name == "H" then
			return value
		end
	end
end

--- Apply both internal monkey-patches using a single `debug.getupvalue` scan.
local function apply_mini_completion_patches()
	local h = get_mini_completion_h()
	if h == nil then
		return
	end

	-- 1. Hide the "S " snippet prefix; show icon in abbr without touching insert text.
	local original_to_items = h.lsp_completion_response_items_to_complete_items
	h.lsp_completion_response_items_to_complete_items = function(items)
		local candidates = original_to_items(items)
		for i, candidate in ipairs(candidates) do
			local item = items[i]
			if item and item.dotfiles_icon then
				candidate.abbr = item.dotfiles_icon
				candidate.abbr_hlgroup = item.abbr_hlgroup
			end
			if type(candidate.menu) == "string" then
				candidate.menu = candidate.menu:gsub("^S ", "")
			end
		end
		return candidates
	end

	-- 2. VS Code-style: debounce normal typing, open immediately on scoped triggers.
	local function is_scoped_trigger(char)
		return char ~= nil and (SCOPED_TRIGGER_CHARS[char] or h.is_lsp_trigger(char, "completion"))
	end

	-- Fork of mini.completion's H.auto_completion; timer is userdata and can't be patched.
	h.auto_completion = function()
		if h.is_disabled() then
			return
		end

		h.completion.timer:stop()

		local is_incomplete = h.completion.lsp.is_incomplete
		local is_trigger = is_scoped_trigger(vim.v.char)
		local force = is_trigger or is_incomplete
		if force then
			h.stop_completion(false, is_incomplete)
		elseif h.pumvisible() then
			return h.stop_completion(true, false, true)
		elseif not h.is_char_keyword(vim.v.char) then
			return h.stop_completion(false)
		end

		h.completion.fallback, h.completion.force = not force, force
		h.completion.text_changed_id = h.text_changed_id + 1

		if h.completion.source == "lsp" then
			return h.trigger_fallback()
		end

		local trigger_kind_name = is_trigger and "TriggerCharacter"
			or (is_incomplete and "TriggerForIncompleteCompletions" or "Invoked")
		local trigger_kind = vim.lsp.protocol.CompletionTriggerKind[trigger_kind_name]
		local trigger_char = trigger_kind_name == "TriggerCharacter" and vim.v.char or nil
		h.completion.lsp.context = { triggerKind = trigger_kind, triggerCharacter = trigger_char }

		local delay = (is_incomplete or is_trigger) and 0 or h.get_config().delay.completion
		h.completion.timer:start(delay, 0, vim.schedule_wrap(h.trigger_twostep))
	end

	-- setup() registers InsertCharPre with the old function reference; replace it.
	for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "MiniCompletion", event = "InsertCharPre" })) do
		vim.api.nvim_del_autocmd(autocmd.id)
	end
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = "MiniCompletion",
		pattern = "*",
		callback = h.auto_completion,
		desc = "Auto show completion",
	})
end

local function pum_visible()
	return vim.fn.pumvisible() ~= 0
end

local on_key_ns

local function setup_pum_navigation_hook()
	if on_key_ns then
		vim.on_key(nil, on_key_ns)
	end
	on_key_ns = vim.api.nvim_create_namespace("dotfiles-completion-pum-nav")

	-- C-n/C-p can't be remapped while the popup is open (:help compl-states).
	-- on_key runs after mappings but can discard the key and feed Down/Up instead.
	local cn = vim.keycode("<C-n>")
	local cp = vim.keycode("<C-p>")

	vim.on_key(function(key, typed)
		if vim.fn.pumvisible() ~= 1 then
			return
		end
		if key == cn or typed == cn then
			vim.schedule(function()
				vim.api.nvim_feedkeys(vim.keycode("<Down>"), "m", false)
			end)
			return ""
		end
		if key == cp or typed == cp then
			vim.schedule(function()
				vim.api.nvim_feedkeys(vim.keycode("<Up>"), "m", false)
			end)
			return ""
		end
	end, on_key_ns)
end

local function setup_keymaps()
	local map_expr = function(lhs, when_pum, otherwise, desc)
		vim.keymap.set("i", lhs, function()
			return pum_visible() and when_pum or otherwise
		end, { expr = true, replace_keycodes = true, desc = desc })
	end

	map_expr("<Tab>", "<C-y>", "<Tab>", "Accept completion or insert tab")
	map_expr("<S-Tab>", "<Up>", "<S-Tab>", "Previous completion item")
	map_expr("<CR>", "<C-y>", "<CR>", "Accept completion or newline")
	setup_pum_navigation_hook()
end

function M.setup()
	hide_kind_column()
	vim.o.pumheight = PUM_MAX_HEIGHT
	vim.o.pummaxwidth = PUM_MAX_WIDTH

	reset_caches()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("dotfiles-completion", { clear = true }),
		callback = reset_caches,
	})

	require("mini.completion").setup({
		delay = {
			completion = COMPLETION_DELAY_MS,
			info = 100,
			signature = 50,
		},
		lsp_completion = {
			process_items = process_items,
		},
		mappings = {
			force_twostep = "<C-Space>",
			force_fallback = "",
		},
	})

	-- noinsert: don't insert the pre-selected item on open; accept only via <C-y>.
	vim.o.completeopt = "menuone,noinsert"

	apply_mini_completion_patches()
	setup_keymaps()
end

return M
