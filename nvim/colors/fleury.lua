vim.o.background = "dark"
vim.g.colors_name = "fleury"

local lush = require("lush")
local spec = require("themes.fleury")

lush(spec)

local links = {
	["@comment"] = "Comment",
	["@comment.documentation"] = "Comment",
	["@constant"] = "Constant",
	["@constant.builtin"] = "Constant",
	["@string"] = "String",
	["@string.escape"] = "SpecialChar",
	["@character"] = "Character",
	["@number"] = "Number",
	["@boolean"] = "Boolean",
	["@float"] = "Float",
	["@function"] = "Function",
	["@function.call"] = "Function",
	["@function.builtin"] = "Function",
	["@method"] = "Function",
	["@keyword"] = "Keyword",
	["@keyword.function"] = "Keyword",
	["@keyword.return"] = "Keyword",
	["@conditional"] = "Conditional",
	["@repeat"] = "Repeat",
	["@operator"] = "Operator",
	["@preproc"] = "PreProc",
	["@include"] = "Include",
	["@type"] = "Type",
	["@type.builtin"] = "Type",
	["@constructor"] = "Type",
	["@property"] = "Identifier",
	["@variable"] = "Identifier",
	["@variable.builtin"] = "Special",
	["@parameter"] = "Identifier",
	["@field"] = "Identifier",
	["@punctuation.delimiter"] = "Delimiter",
	["@punctuation.bracket"] = "Delimiter",
	["@punctuation.special"] = "SpecialChar",
	["@tag"] = "Keyword",
	["@tag.attribute"] = "Identifier",
	["@namespace"] = "Type",
	["@module"] = "Type",
	["@lsp.type.macro"] = "Macro",
	["@lsp.type.function"] = "Function",
	["@lsp.type.method"] = "Function",
	["@lsp.type.type"] = "Type",
	["@lsp.type.class"] = "Type",
	["@lsp.type.struct"] = "Type",
	["@lsp.type.namespace"] = "Type",
}

for group, target in pairs(links) do
	vim.api.nvim_set_hl(0, group, { link = target })
end
