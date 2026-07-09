-- Minimalist Tree-sitter highlighting, modeled on Nikita Prokopov's essay
-- "I am sorry, but everyone is getting syntax highlighting wrong":
-- https://tonsky.me/blog/syntax-highlighting/
--
-- Only a handful of standard highlight groups are used, and every capture
-- is `link`ed to one of them -- never a hardcoded hex color -- so the
-- result always follows whatever colorscheme is active.
local M = {}

-- Keywords are structure, not meaning: the logic after `if`/`return`/`import`
-- matters, not the keyword itself. Variable/call/field references are ~75%
-- of any file -- field access (`vim.o`, `obj.prop`) is just as common as a
-- plain variable and just as much "usage", not a declaration -- so all of it
-- gets stripped to `Normal` rather than earning its own color.
local strip_to_normal = {
	"@keyword",
	"@keyword.modifier",
	"@keyword.type",
	"@keyword.repeat",
	"@keyword.conditional",
	"@keyword.import",
	"@keyword.directive",
	"@keyword.exception",
	"@include",
	"@conditional",
	"@repeat",
	"@exception",
	"@variable",
	"@variable.parameter",
	"@variable.member",
	"@property",
	"@field",
	"@function.call",
	"@method.call",
	-- The ecma/javascript grammar spells method calls `@function.method.call`
	-- (not `@method.call`) and builtin calls (`Array.from`, `Object.keys`)
	-- `@function.builtin` -- both are invocations, i.e. usage, not a
	-- declaration, so they belong here alongside the other `.call` groups.
	"@function.method.call",
	"@function.builtin",
	-- `@constant` in the ecma/javascript grammar is a pure naming-convention
	-- heuristic ("identifier looks SCREAMING_SNAKE_CASE"), applied at every
	-- reference to such a name, not just its declaration -- structurally
	-- it's just a variable reference (the 75% rule), so a naming style
	-- shouldn't earn it a color real literals don't get.
	"@constant",
	-- JSX/TSX tag names and prop names are references too: `<div>` and
	-- `<Skeleton>` are both just "using a name", same as a variable or a
	-- function call, and a prop name is a field access. Without this,
	-- lowercase (@tag.builtin) and uppercase (@tag) tags inconsistently
	-- pick up two different colors from the colorscheme's own tag/keyword
	-- links for what is semantically the same thing.
	"@tag",
	"@tag.builtin",
	"@tag.attribute",
}

-- Delimiters and operators are scaffolding. Dimming them to `Comment` lets
-- identifiers -- the part worth reading -- take center stage. This also
-- covers operators spelled as keywords (`typeof`, `instanceof`, `as`, the
-- ternary `?`/`:`) so all operator-shaped tokens are muted uniformly
-- instead of only the symbolic ones.
local dim_to_comment = {
	"@punctuation.delimiter",
	"@punctuation.bracket",
	"@punctuation.special",
	"@operator",
	"@keyword.operator",
	"@keyword.conditional.ternary",
	"@tag.delimiter",
}

-- What's left after the strip-down: function/method declarations and
-- literals, kept distinct enough to pass the reverse lookup test (close
-- your eyes, name what each color means) without adding a color per token
-- type.
local reference_points = {
	["@function"] = "Function",
	["@method"] = "Function",
	-- The ecma/javascript grammar spells method declarations
	-- `@function.method` (object/class method definitions), not `@method`.
	["@function.method"] = "Function",
	["@string"] = "String",
	["@string.documentation"] = "String",
	["@string.escape"] = "String",
	["@number"] = "Constant",
	["@float"] = "Constant",
	["@boolean"] = "Constant",
	["@constant.builtin"] = "Constant",
	["@type"] = "Type",
	["@type.builtin"] = "Type",
}

-- Neovim resolves `@capture.lang` before falling back to plain `@capture`
-- (:h treesitter-highlight-groups). Colorschemes sometimes hardcode a
-- language-specific variant (e.g. ef-themes hardcodes `@tag.tsx`), which
-- would otherwise silently shadow every override below for that language.
-- Setting both forms for every installed parser closes that gap.
local function installed_languages()
	local langs = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("parser/*", true)) do
		langs[vim.fn.fnamemodify(path, ":t:r")] = true
	end
	return langs
end

local function set_hl_all_langs(langs, group, target)
	vim.api.nvim_set_hl(0, group, { link = target })
	for lang in pairs(langs) do
		vim.api.nvim_set_hl(0, group .. "." .. lang, { link = target })
	end
end

---@param opts? { comment_hl?: string }
local function apply(opts)
	opts = opts or {}
	-- Comments explain what the code can't; they earn attention rather than
	-- fading into gray. Default to `Todo` (usually bold/inverted); pass
	-- comment_hl = "String" or "Constant" to pick a different accent.
	local comment_hl = opts.comment_hl or "Todo"
	local langs = installed_languages()

	for _, group in ipairs(strip_to_normal) do
		set_hl_all_langs(langs, group, "Normal")
	end

	for _, group in ipairs(dim_to_comment) do
		set_hl_all_langs(langs, group, "Comment")
	end

	for group, target in pairs(reference_points) do
		set_hl_all_langs(langs, group, target)
	end

	set_hl_all_langs(langs, "@comment", comment_hl)
	set_hl_all_langs(langs, "@comment.documentation", comment_hl)
end

---@param opts? { comment_hl?: string }
function M.setup(opts)
	apply(opts)

	-- Reapply on every ColorScheme change so switching themes never leaves
	-- stale links or Christmas-lights highlighting behind.
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("MinimalSyntax", { clear = true }),
		callback = function()
			apply(opts)
		end,
	})
end

return M
