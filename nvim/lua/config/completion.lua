-- Completion: mini.completion (LSP popup menu with auto-open delay)

local M = {}

-- Delay (ms) before the completion popup auto-opens while typing.
local COMPLETION_DELAY_MS = 500
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

local function resolve_hl_attrs(hl_name)
	-- link=false already resolves the chain; no recursion needed.
	return vim.api.nvim_get_hl(0, { name = hl_name, link = false })
end

local function kind_icon_hlgroup(mini_icons_hl)
	local cached = kind_hl_cache[mini_icons_hl]
	if cached then
		return cached
	end

	local src = resolve_hl_attrs(mini_icons_hl)
	local dst_hl = "DotfilesPmenuKindIcon_" .. mini_icons_hl

	vim.api.nvim_set_hl(0, dst_hl, {
		fg = src.fg,
		ctermfg = src.ctermfg,
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

		-- Icon in the left column (abbr), colored per kind; name stays neutral in menu.
		item.label = icon
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

	-- 1. Hide the "S " snippet prefix from the menu column.
	local original_to_items = h.lsp_completion_response_items_to_complete_items
	h.lsp_completion_response_items_to_complete_items = function(items)
		local candidates = original_to_items(items)
		for _, candidate in ipairs(candidates) do
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

local function setup_keymaps()
	vim.keymap.set("i", "<Tab>", function()
		return vim.fn.pumvisible() == 1 and "<C-y>" or "<Tab>"
	end, { expr = true, replace_keycodes = true, desc = "Accept completion or insert tab" })

	vim.keymap.set("i", "<S-Tab>", function()
		return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
	end, { expr = true, replace_keycodes = true, desc = "Previous completion item" })

	vim.keymap.set("i", "<CR>", function()
		return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
	end, { expr = true, replace_keycodes = true, desc = "Accept completion or newline" })
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
		},
	})

	apply_mini_completion_patches()
	setup_keymaps()
end

return M
