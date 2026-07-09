local fff_config = require("config.fff")
local selabel = require("config.selabel")

local patterns = {
	rust = {
		["function"] = [=[\bfn\s+@]=],
		["type"] = [=[\b(?:struct|enum|union|type)\s+@]=],
		["interface"] = [=[\btrait\s+@]=],
		["declaration"] = [=[\b(?:let\s+(?:mut\s+)?|(?:pub\s+)?(?:const|static)\s+(?:mut\s+)?)@]=],
	},
	go = {
		["function"] = [=[^func\s+(?:\([^)]*\)\s*)?@]=],
		["type"] = [=[^type\s+@]=],
		["interface"] = [=[^type\s+@\w*\s+interface\b]=],
		["declaration"] = [=[(?:\b(?:var|const)\s+@|^\s*@\w*\s*:=)]=],
	},
	python = {
		["function"] = [=[^\s*(?:async\s+)?def\s+@]=],
		["type"] = [=[^\s*class\s+@]=],
		["declaration"] = [=[^\s*@\w*\s*(?::[^=]*)?=[^=]]=],
	},
	c = {
		["function"] = [=[^[A-Za-z_][\w \t\*]*\b@\w*\s*\(]=],
		["type"] = [=[\b(?:struct|union|enum)\s+@]=],
		["declaration"] = [=[^[A-Za-z_][\w \t\*]*\b@\w*\s*(?:[;=\[]|\([^;]*\)\s*;)]=],
	},
	cpp = {
		["function"] = [=[^[A-Za-z_][\w \t\*&:<>,]*\b@\w*\s*\(]=],
		["type"] = [=[\b(?:class|struct|union|enum(?:\s+class)?)\s+@]=],
		["declaration"] = [=[^[A-Za-z_][\w \t\*&:<>,]*\b@\w*\s*(?:[;=\[]|\([^;]*\)\s*;)]=],
	},
	java = {
		["function"] = [=[^\s*(?:(?:public|private|protected|static|final|abstract|synchronized|native|default)\s+)*[\w<>\[\],\.\?]+\s+@\w*\s*\(]=],
		["type"] = [=[\b(?:class|enum|record)\s+@]=],
		["interface"] = [=[\binterface\s+@]=],
		["declaration"] = [=[^\s*(?:(?:public|private|protected|static|final|volatile|transient)\s+)*[\w<>\[\],\.\?]+\s+@\w*\s*[;=]]=],
	},
	kotlin = {
		["function"] = [=[\bfun\s+(?:<[^>]*>\s*)?(?:\w+\.)?@]=],
		["type"] = [=[\b(?:(?:data|sealed|enum|value|inner|open|abstract)\s+)*(?:class|object)\s+@]=],
		["interface"] = [=[\b(?:(?:sealed|fun)\s+)?interface\s+@]=],
		["declaration"] = [=[\b(?:val|var)\s+@]=],
	},
	["js/ts"] = {
		-- An arrow function is only distinguishable from a plain constant by what
		-- follows the `=`, and the regex crate has no lookahead to peek with.
		-- `\x0A` rather than `\n`: fff treats a literal `\n` in the pattern as a
		-- request for multiline search, which merges adjacent hits into one result.
		["function"] = [=[(?:\b(?:async\s+)?function\s*\*?\s+@\w*[ \t]*\(|\b(?:const|let|var)\s+@\w*[ \t]*(?::[^=\x0A]*)?=[ \t]*(?:async[ \t]+)?(?:function\b|<[^>\x0A]*>[ \t]*\(|\([^)\x0A]*\)[ \t]*(?::[^=\x0A]*)?=>|\([ \t]*$|[\w$]+[ \t]*=>|[\w$.]+\([ \t]*(?:async[ \t]+)?\())]=],
		["type"] = [=[\b(?:class|type|enum)\s+@]=],
		["interface"] = [=[\binterface\s+@]=],
		["declaration"] = [=[\b(?:const|let|var)\s+@]=],
	},
	zig = {
		["function"] = [=[\bfn\s+@]=],
		["type"] = [=[\bconst\s+@\w*\s*=\s*(?:packed\s+|extern\s+)?(?:struct|enum|union)\b]=],
		["declaration"] = [=[\b(?:const|var)\s+@]=],
	},
	odin = {
		["function"] = [=[^\s*@\w*\s*::\s*(?:inline\s+)?proc\b]=],
		["type"] = [=[^\s*@\w*\s*::\s*(?:distinct\s+)?(?:struct|union|enum|bit_set)\b]=],
		["declaration"] = [=[^\s*@\w*\s*:(?:[:=]|\s*[\w\^\[])]=],
	},
	lua = {
		["function"] = [=[\b(?:(?:local\s+)?function\s+(?:[\w.]+\.)?|(?:local\s+)?[\w.]+\.)@\w*(?:\s*\(|\s*=\s*function\b)]=],
		["type"] = [=[---@(?:class|alias)\s+@]=],
		["declaration"] = [=[\blocal\s+@]=],
	},
}

local lang_globs = {
	rust = { "*.rs" },
	go = { "*.go" },
	python = { "*.py" },
	c = { "*.c", "*.h" },
	cpp = { "*.cpp", "*.cc", "*.cxx", "*.h", "*.hpp", "*.hh" },
	java = { "*.java" },
	kotlin = { "*.kt", "*.kts" },
	["js/ts"] = { "*.js", "*.ts", "*.jsx", "*.tsx", "*.mjs", "*.cjs" },
	zig = { "*.zig" },
	odin = { "*.odin" },
	lua = { "*.lua" },
}

local filetype_to_lang = {
	rust = "rust",
	go = "go",
	python = "python",
	c = "c",
	cpp = "cpp",
	cxx = "cpp",
	java = "java",
	kotlin = "kotlin",
	javascript = "js/ts",
	javascriptreact = "js/ts",
	typescript = "js/ts",
	typescriptreact = "js/ts",
	zig = "zig",
	odin = "odin",
	lua = "lua",
}

local lang_label = {
	c = "c",
	cpp = "p",
	go = "g",
	java = "j",
	["js/ts"] = "t",
	kotlin = "k",
	lua = "l",
	odin = "o",
	python = "y",
	rust = "r",
	zig = "z",
}

local kind_label = {
	["function"] = "f",
	["type"] = "t",
	["interface"] = "i",
	["declaration"] = "d",
}

local function labels_for(items, key_map)
	local labels = {}
	for _, item in ipairs(items) do
		table.insert(labels, key_map[item])
	end
	return labels
end

local wrapped = false

local function ensure_wrapped()
	if wrapped then
		return true
	end
	local ok, grep = pcall(require, "fff.picker_ui.grep_renderer")
	if not ok then
		vim.notify("fff.picker_ui.grep_renderer missing; symbol search needs fff >= 0.9", vim.log.levels.ERROR)
		return false
	end
	local state = require("fff.picker_ui.picker_ui_state").state
	local orig = grep.search
	grep.search = function(query, file_offset, page_size, config, grep_mode)
		local tmpl = state.config and state.config.symbol_template
		local globs = state.config and state.config.symbol_globs
		if tmpl and grep_mode == "regex" then
			local ci = query:match("%u") and "" or "(?i)"
			local name = query
			query = ci .. (tmpl:gsub("@", function()
				return name
			end))
			if globs and #globs > 0 then
				query = table.concat(globs, " ") .. " " .. query
			end
		end
		return orig(query, file_offset, page_size, config, grep_mode)
	end

	-- Suppress cross-mode filename suggestions when grep returns nothing.
	local file_picker = require("fff.file_picker")
	local orig_files = file_picker.search_files_paginated
	file_picker.search_files_paginated = function(query, ...)
		if state.mode == "grep" and state.config and state.config.symbol_template then
			return {}
		end
		return orig_files(query, ...)
	end

	-- fff's grep empty state always says "Start typing…" even with a query.
	local picker_ui = require("fff.picker_ui.picker_ui")
	local orig_render_list = picker_ui.render_list
	picker_ui.render_list = function()
		if not picker_ui.state.active then
			return
		end
		if
			state.mode == "grep"
			and state.config
			and state.config.symbol_template
			and state.query ~= ""
			and #state.filtered_items == 0
		then
			local content = { "", "  No matching symbols", "" }
			vim.api.nvim_set_option_value("modifiable", true, { buf = state.list_buf })
			vim.api.nvim_buf_set_lines(state.list_buf, 0, -1, false, content)
			vim.api.nvim_set_option_value("modifiable", false, { buf = state.list_buf })
			vim.api.nvim_buf_clear_namespace(state.list_buf, state.ns_id, 0, -1)
			pcall(vim.api.nvim_buf_set_extmark, state.list_buf, state.ns_id, 1, 0, {
				end_row = 2,
				end_col = 0,
				hl_group = "Comment",
			})
			state.line_to_item = {}
			state.item_to_lines = {}
			state.last_render_ctx = nil
			return
		end
		return orig_render_list()
	end

	wrapped = true
	return true
end

local function sorted_languages()
	local langs = vim.tbl_keys(patterns)
	table.sort(langs)
	local ft = vim.bo.filetype
	local current = filetype_to_lang[ft]
	if current then
		local filtered = {}
		table.insert(filtered, current)
		for _, lang in ipairs(langs) do
			if lang ~= current then
				table.insert(filtered, lang)
			end
		end
		return filtered
	end
	return langs
end

local function open_symbol_search(lang, kind)
	local tmpl = patterns[lang] and patterns[lang][kind]
	if not tmpl then
		return
	end
	if not ensure_wrapped() then
		return
	end
	require("fff").live_grep({
		cwd = fff_config.base_path(),
		title = lang .. " " .. kind,
		grep = { modes = { "regex" }, smart_case = false },
		symbol_template = tmpl,
		symbol_globs = lang_globs[lang],
	})
end

local function pick_kind(lang)
	local kinds = vim.tbl_keys(patterns[lang])
	table.sort(kinds)
	selabel.select(kinds, labels_for(kinds, kind_label), "Symbol kind", function(kind)
		if kind then
			open_symbol_search(lang, kind)
		end
	end)
end

local function pick_language()
	local langs = sorted_languages()
	selabel.select(langs, labels_for(langs, lang_label), "Language", function(lang)
		if lang then
			pick_kind(lang)
		end
	end)
end

vim.keymap.set("n", "<leader>sk", pick_language, { desc = "Search symbol definition" })
