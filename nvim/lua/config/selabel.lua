local M = {}

M.labels = {
	"c", "p", "s", "d", "n", "u", "l", "t", ".", "T", "P",
	"f", "a", "j", "k", ";", "r", "e", "w", "q", "i", "o", "v", "x", "z", "m", ",", "/",
}

M.win_opts = {
	relative = "cursor",
	style = "minimal",
	border = "single",
	title_pos = "center",
	row = 1,
	col = 1,
}

---Neovim's own `vim.ui.select`, captured before selabel injects over it.
local builtin_select = vim.ui.select

---How many labels selabel currently has. It refuses to show anything when there
---are more items than labels, and drops `on_choice` on the floor when it does --
---which hangs any caller that wrapped the select in a coroutine (neogit does).
local label_count = #M.labels

local function inject()
	local selabel = require("selabel")

	vim.ui.select = function(items, opts, on_choice)
		if #items > label_count then
			return builtin_select(items, opts, on_choice)
		end

		selabel.select(items, opts, on_choice)

		-- selabel opens its float unfocused and then blocks in `getcharstr()`.
		-- While typeahead is pending -- e.g. right after a neogit popup key --
		-- nvim skips the flush, so the window stays invisible until some
		-- unrelated key forces a redraw. Force it ourselves instead.
		vim.schedule(function()
			vim.cmd("redraw")
		end)
	end
end

function M.setup(opts)
	opts = opts or {}
	-- selabel deep-extends its options, so the label list never shrinks.
	label_count = math.max(label_count, #(opts.labels or M.labels))

	require("selabel").setup(vim.tbl_extend("force", {
		labels = M.labels,
		hack = 10,
		win_opts = M.win_opts,
	}, opts))

	inject()
end

---Defer select so leader-chord keys drain before selabel's getcharstr loop.
function M.select(items, labels, prompt, on_choice)
	M.setup({ labels = labels })
	vim.schedule(function()
		vim.ui.select(items, { prompt = prompt }, function(item, idx)
			M.setup({})
			if on_choice then
				on_choice(item, idx)
			end
		end)
	end)
end

return M
