local lush = require("lush")
local hsl = lush.hsl

local bg = hsl("#202020")
local bg_alt = hsl("#212121")
-- local bg_cursorline = hsl("#1F1F27")
local bg_cursorline = hsl("#2F2F37")
local bg_visual = hsl("#2D3640")
local bg_search = hsl("#315268")
local bg_token = hsl("#2F2F37")
local fg = hsl("#A08563")
local fg_dim = hsl("#686868")
local fg_faint = hsl("#404040")
local fg_accent = hsl("#CB9401")
local green = hsl("#6B8E23")
local olive = hsl("#70971E")
local sand = hsl("#DAB98F")
local amber = hsl("#AC7B0B")
local rust = hsl("#CC5735")
local teal = hsl("#478980")
local gold = hsl("#D8A51D")
local op = hsl("#907553")
local red = hsl("#FF0000")
local rose = hsl("#DE2368")
local yellow = hsl("#EFaf2F")
local secondary = hsl("#2F2E34")

return lush(function()
	return {
		Normal { fg = fg, bg = bg },
		NormalNC { Normal },
		CursorLine { bg = bg_cursorline },
		CursorColumn { CursorLine },
		ColorColumn { bg = bg_cursorline.da(10) },
		Conceal { fg = fg_faint },
		CursorLineNr { fg = fg_accent, bg = bg_alt, bold = true },
		LineNr { fg = fg_faint, bg = bg_alt },
		SignColumn { fg = fg_faint, bg = bg },
		FoldColumn { fg = fg_faint, bg = bg },
		Folded { fg = fg_dim, bg = bg_cursorline },
		NonText { fg = bg_cursorline.li(35) },
		EndOfBuffer { NonText },
		Whitespace { fg = bg_cursorline.li(20) },

		StatusLine { fg = fg_accent, bg = bg_cursorline },
		StatusLineNC { fg = fg_dim, bg = bg_cursorline },
		WinSeparator { fg = bg_cursorline.li(20), bg = bg },
        WinBar { fg = fg_accent, bg = bg },
		VertSplit { WinSeparator },
		TabLine { fg = fg_dim, bg = bg_cursorline },
		TabLineFill { fg = fg_dim, bg = bg },
		TabLineSel { fg = fg_accent, bg = bg, bold = true },

		Visual { bg = bg_visual },
		VisualNOS { Visual },
		Search { fg = sand, bg = bg_search },
		CurSearch { fg = bg, bg = sand, bold = true },
		IncSearch { CurSearch },
		Substitute { fg = bg, bg = rust, bold = true },
		MatchParen { fg = yellow, bg = bg_token, bold = true },

		Pmenu { fg = fg, bg = bg_cursorline },
		PmenuSel { fg = sand, bg = bg_visual },
		PmenuSbar { bg = bg_cursorline },
		PmenuThumb { bg = fg_dim },

		Comment { fg = fg_dim },
		Constant { fg = green },
		String { Constant },
		Character { Constant },
		Number { Constant },
		Boolean { Constant },
		Float { Constant },
		Identifier { fg = fg },
		Function { fg = rust },
		Statement { fg = amber },
		Conditional { Statement },
		Repeat { Statement },
		Label { fg = fg_accent },
		Operator { fg = op },
		Keyword { fg = amber },
		Exception { fg = rust },
		PreProc { fg = sand },
		Include { PreProc },
		Define { fg = teal },
		Macro { fg = teal },
		Type { fg = gold },
		StorageClass { Type },
		Structure { Type },
		Typedef { Type },
		Special { fg = fg_accent },
		SpecialChar { fg = red },
		Delimiter { fg = op },
		SpecialComment { fg = olive },
		Underlined { fg = teal, underline = true },
		Title { fg = sand, bold = true },
		Directory { fg = teal },

		DiagnosticError { fg = rust },
		DiagnosticWarn { fg = yellow },
		DiagnosticInfo { fg = teal },
		DiagnosticHint { fg = olive },
		DiagnosticOk { fg = green },
		DiagnosticVirtualTextError { fg = rust, bg = bg },
		DiagnosticVirtualTextWarn { fg = yellow, bg = bg },
		DiagnosticVirtualTextInfo { fg = teal, bg = bg },
		DiagnosticVirtualTextHint { fg = olive, bg = bg },
		DiagnosticUnderlineError { sp = rust, undercurl = true },
		DiagnosticUnderlineWarn { sp = yellow, undercurl = true },
		DiagnosticUnderlineInfo { sp = teal, undercurl = true },
		DiagnosticUnderlineHint { sp = olive, undercurl = true },

		DiffAdd { fg = green, bg = bg.mix(green, 18) },
		DiffChange { fg = sand, bg = bg.mix(bg_search, 55) },
		DiffDelete { fg = rose, bg = bg.mix(rose, 18) },
		DiffText { fg = fg_accent, bg = bg_visual },

		Error { fg = rust, bg = bg },
		ErrorMsg { fg = rust, bg = bg },
		WarningMsg { fg = yellow, bg = bg },
		MoreMsg { fg = green, bg = bg },
		Question { fg = olive, bg = bg },
		Todo { fg = bg, bg = fg_accent, bold = true },
    }
end)
