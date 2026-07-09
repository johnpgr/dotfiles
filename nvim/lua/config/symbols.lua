local fff_config = require("config.fff")
local selabel = require("config.selabel")

local patterns = {
	rust = {
		["function"] = { [=[\bfn\s+]=], "" },
		["type"] = { [=[\b(?:struct|enum|union|type)\s+]=], "" },
		["interface"] = { [=[\btrait\s+]=], "" },
	},
	go = {
		["function"] = { [=[^func\s+(?:\([^)]*\)\s*)?]=], "" },
		["type"] = { [=[^type\s+]=], "" },
		["interface"] = { [=[^type\s+]=], [=[\w*\s+interface\b]=] },
	},
	python = {
		["function"] = { [=[^\s*(?:async\s+)?def\s+]=], "" },
		["type"] = { [=[^\s*class\s+]=], "" },
	},
	c = {
		["function"] = { [=[^[A-Za-z_][\w \t\*]*\b]=], [=[\w*\s*\(]=] },
		["type"] = { [=[\b(?:struct|union|enum)\s+]=], "" },
	},
	cpp = {
		["function"] = { [=[^[A-Za-z_][\w \t\*&:<>,]*\b]=], [=[\w*\s*\(]=] },
		["type"] = { [=[\b(?:class|struct|union|enum(?:\s+class)?)\s+]=], "" },
	},
	java = {
		["function"] = {
			[=[^\s*(?:(?:public|private|protected|static|final|abstract|synchronized|native|default)\s+)*[\w<>\[\],\.\?]+\s+]=],
			[=[\w*\s*\(]=],
		},
		["type"] = { [=[\b(?:class|enum|record)\s+]=], "" },
		["interface"] = { [=[\binterface\s+]=], "" },
	},
	kotlin = {
		["function"] = { [=[\bfun\s+(?:<[^>]*>\s*)?(?:\w+\.)?]=], "" },
		["type"] = { [=[\b(?:(?:data|sealed|enum|value|inner|open|abstract)\s+)*(?:class|object)\s+]=], "" },
		["interface"] = { [=[\b(?:(?:sealed|fun)\s+)?interface\s+]=], "" },
	},
	javascript = {
		["function"] = { [=[\b(?:(?:async\s+)?function\s*\*?\s+|(?:const|let|var)\s+)]=], [=[\w*\s*[=(]]=] },
		["type"] = { [=[\bclass\s+]=], "" },
	},
	typescript = {
		["function"] = { [=[\b(?:(?:async\s+)?function\s*\*?\s+|(?:const|let|var)\s+)]=], [=[\w*\s*[=(]]=] },
		["type"] = { [=[\b(?:class|type|enum)\s+]=], "" },
		["interface"] = { [=[\binterface\s+]=], "" },
	},
	zig = {
		["function"] = { [=[\bfn\s+]=], "" },
		["type"] = { [=[\bconst\s+]=], [=[\w*\s*=\s*(?:packed\s+|extern\s+)?(?:struct|enum|union)\b]=] },
	},
	odin = {
		["function"] = { [=[^\s*]=], [=[\w*\s*::\s*(?:inline\s+)?proc\b]=] },
		["type"] = { [=[^\s*]=], [=[\w*\s*::\s*(?:distinct\s+)?(?:struct|union|enum|bit_set)\b]=] },
	},
	lua = {
		["function"] = {
			[=[\b(?:(?:local\s+)?function\s+(?:[\w.]+\.)?|(?:local\s+)?[\w.]+\.)]=],
			[=[\w*(?:\s*\(|\s*=\s*function\b)]=],
		},
		["type"] = { [=[---@(?:class|alias)\s+]=], "" },
	},
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
	javascript = "javascript",
	javascriptreact = "javascript",
	typescript = "typescript",
	typescriptreact = "typescript",
	zig = "zig",
	odin = "odin",
	lua = "lua",
}

local lang_label = {
	c = "c",
	cpp = "p",
	go = "g",
	java = "j",
	javascript = "n",
	kotlin = "k",
	lua = "l",
	odin = "o",
	python = "y",
	rust = "r",
	typescript = "T",
	zig = "z",
}

local kind_label = {
	["function"] = "f",
	["type"] = "t",
	["interface"] = "i",
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
		if tmpl and grep_mode == "regex" then
			local ci = query:match("%u") and "" or "(?i)"
			query = ci .. tmpl.prefix .. query .. tmpl.suffix
		end
		return orig(query, file_offset, page_size, config, grep_mode)
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
		symbol_template = { prefix = tmpl[1], suffix = tmpl[2] },
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
	selabel.select(langs, labels_for(langs, lang_label), "Search symbol", function(lang)
		if lang then
			pick_kind(lang)
		end
	end)
end

vim.keymap.set("n", "<leader>sk", pick_language, { desc = "Search symbol definition" })
