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

function M.setup(opts)
	require("selabel").setup(vim.tbl_extend("force", {
		labels = M.labels,
		hack = 1,
		win_opts = M.win_opts,
	}, opts or {}))
end

---Defer select so leader-chord keys drain before selabel's getcharstr loop.
function M.select(items, labels, prompt, on_choice)
	M.setup({ labels = labels, hack = 10 })
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
