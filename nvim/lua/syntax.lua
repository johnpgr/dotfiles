-- Minimalist Tree-sitter highlighting, modeled on Nikita Prokopov's essay
-- "I am sorry, but everyone is getting syntax highlighting wrong":
-- https://tonsky.me/blog/syntax-highlighting/
--
-- Only a handful of standard highlight groups are used, and every capture
-- is `link`ed to one of them -- never a hardcoded hex color -- so the
-- result always follows whatever colorscheme is active.
local M = {}

-- Variable/call/field references are ~75% of any file -- field access
-- (`vim.o`, `obj.prop`) is just as common as a plain variable and just as
-- much "usage", not a declaration -- so all of it gets stripped to `Normal`
-- rather than earning its own color. Keywords are handled separately below
-- (they keep their classic per-category colors).
local strip_to_normal = {
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
	-- Numeric literals aren't distinguished from any other value either.
	"@number",
	"@float",
	-- JSX/TSX tag names and prop names are references too: `<div>` and
	-- `<Skeleton>` are both just "using a name", same as a variable or a
	-- function call, and a prop name is a field access. Without this,
	-- lowercase (@tag.builtin) and uppercase (@tag) tags inconsistently
	-- pick up two different colors from the colorscheme's own tag/keyword
	-- links for what is semantically the same thing.
	"@tag",
	"@tag.builtin",
	"@tag.attribute",
	-- The jsx grammar defaults tag text content to `@none` (no highlight),
	-- but overrides that for text inside semantic tag names -- `<h1>`-`<h6>`,
	-- `<strong>`, `<em>`, `<code>`, `<a>`, etc. -- treating it like markdown.
	-- JSX isn't markdown; text between tags should never pick up a color
	-- just because of the enclosing tag's name.
	"@markup.heading",
	"@markup.heading.1",
	"@markup.heading.2",
	"@markup.heading.3",
	"@markup.heading.4",
	"@markup.heading.5",
	"@markup.heading.6",
	"@markup.strong",
	"@markup.italic",
	"@markup.strikethrough",
	"@markup.underline",
	"@markup.raw",
	"@markup.link.label",
	-- Punctuation (`;(){}<>`) is pure scaffolding -- no highlighting at all,
	-- not even a muted one, so identifiers are the only thing carrying
	-- color. Operators (`=`, `??`, `typeof`, ternary `?`/`:`, ...) are
	-- handled separately below, via the standard `Operator` group.
	"@punctuation.delimiter",
	"@punctuation.bracket",
	"@punctuation.special",
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
	-- `null`/`undefined`/`true`/`false` are reserved language sentinels, not
	-- user data -- grouped with keywords instead of literal constants.
	["@boolean"] = "Keyword",
	["@constant.builtin"] = "Keyword",
	-- Types share the `Function` link rather than getting their own group.
	["@type"] = "Function",
	["@type.builtin"] = "Function",
	-- Operators get Vim's standard `Special` group -- distinct from both
	-- the unhighlighted punctuation and the muted `Comment` used elsewhere.
	-- (`Operator` itself is just bold-on-Normal in some colorschemes, e.g.
	-- ef-dream, which isn't actually a distinct color.) Includes operators
	-- spelled as keywords (`typeof`, `instanceof`, `as`) and the ternary
	-- `?`/`:`, so every operator-shaped token matches.
	["@operator"] = "Special",
	["@keyword.operator"] = "Special",
	["@keyword.conditional.ternary"] = "Special",
	-- Every keyword variant shares one `Keyword` link -- `if`/`for`/`import`/
	-- `try` all look the same as each other, just distinct from identifiers.
	["@keyword"] = "Keyword",
	["@keyword.modifier"] = "Keyword",
	["@keyword.type"] = "Keyword",
	["@keyword.repeat"] = "Keyword",
	["@keyword.conditional"] = "Keyword",
	["@keyword.import"] = "Keyword",
	["@keyword.directive"] = "Keyword",
	["@keyword.exception"] = "Keyword",
	["@include"] = "Keyword",
	["@conditional"] = "Keyword",
	["@repeat"] = "Keyword",
	["@exception"] = "Keyword",
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
	-- fading into gray. Default to `Define`; pass comment_hl to override.
	local comment_hl = opts.comment_hl or "Define"
	local langs = installed_languages()

	for _, group in ipairs(strip_to_normal) do
		set_hl_all_langs(langs, group, "Normal")
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
