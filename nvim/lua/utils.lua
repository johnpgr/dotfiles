local M = {}

M.config_db_uri = vim.fn.stdpath("data") .. "/nvim_config.db"
M.is_neovide = vim.g.neovide ~= nil
M.is_kitty = os.getenv("TERM") == "xterm-kitty"
M.default_picker_config = {
	borderchars = {
		{ "─", "│", "─", "│", "┌", "┐", "┘", "└" },
		prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
		results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
		preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
	},
	theme = "dropdown",
	previewer = false,
	layout_config = {
		width = 0.6,
	},
	results_title = false,
    prompt_title = "",
}

-- Fuzzy find within the current buffer with live preview navigation
--
-- This function provides an enhanced telescope fuzzy finder for the current buffer that:
-- - Automatically jumps to selected lines as you navigate through results
-- - Centers the cursor on the target line when jumping
-- - Updates the search register (/) with the current search term for highlighting
-- - Supports sending results to quickfix list with <C-q>
-- - Uses exact matching instead of fuzzy matching for more precise results
--
-- Key features:
-- - Live preview: Cursor jumps to lines as you move through search results
-- - Search term highlighting: Automatically sets hlsearch with current query
-- - Safe navigation: Validates line numbers and cursor positions before jumping
-- - Quickfix integration: Send all matching results to quickfix list
-- - Mark integration: Sets a mark (') before jumping to preserve jump history
--
-- Keybindings:
-- - <Down>/<C-n>/j: Move to next result and jump to line
-- - <Up>/<C-p>/k: Move to previous result and jump to line
-- - <CR>: Jump to selected line and close picker
-- - <C-q>: Send all results to quickfix list and open it
function M.fuzzy_find_current_buffer()
	local original_win = vim.api.nvim_get_current_win()
	local original_bufnr = vim.api.nvim_get_current_buf()

	local action_state = require("telescope.actions.state")
	local actions = require("telescope.actions")

	local opts = vim.tbl_extend("force", M.default_picker_config, {
		fuzzy = false,
		exact = true,
		attach_mappings = function(prompt_bufnr, map)
			local function jump_to_selection()
				local selection = action_state.get_selected_entry()
				if selection and selection.lnum then
					local line_count = vim.api.nvim_buf_line_count(original_bufnr)

					if selection.lnum > 0 and selection.lnum <= line_count then
						local line = vim.api.nvim_buf_get_lines(
							original_bufnr,
							selection.lnum - 1,
							selection.lnum,
							false
						)[1] or ""
						local col = math.min(selection.col or 0, #line)

						vim.cmd("normal! m'")
						vim.api.nvim_win_set_cursor(original_win, { selection.lnum, col })

						if vim.api.nvim_win_is_valid(original_win) then
							vim.api.nvim_win_call(original_win, function()
								vim.cmd("normal! zz")
							end)
						end
					end
				end
			end

			actions.select_default:replace(function()
				jump_to_selection()
				actions.close(prompt_bufnr)
			end)

			local move_selection_next = function()
				actions.move_selection_next(prompt_bufnr)
				jump_to_selection()
			end

			local move_selection_previous = function()
				actions.move_selection_previous(prompt_bufnr)
				jump_to_selection()
			end

			map("i", "<Down>", move_selection_next)
			map("i", "<C-n>", move_selection_next)
			map("i", "<Up>", move_selection_previous)
			map("i", "<C-p>", move_selection_previous)

			map("n", "j", move_selection_next)
			map("n", "k", move_selection_previous)

			map("i", "<C-q>", function()
				actions.send_to_qflist(prompt_bufnr)
				vim.cmd("copen")
			end)

			map("n", "<C-q>", function()
				actions.send_to_qflist(prompt_bufnr)
				vim.cmd("copen")
			end)

			return true
		end,
		on_input_filter_cb = function(prompt)
			if prompt and #prompt > 0 then
				vim.fn.setreg("/", prompt)
				vim.cmd("let v:hlsearch=1")
			end
			return prompt
		end,
	})
	require("telescope.builtin").current_buffer_fuzzy_find(opts)
end

function M.jump_to_error_loc()
	local line = vim.fn.getline(".")
	local file, lnum, col = string.match(line, "([^:]+):(%d+):(%d+)")

	if not (file and lnum and col) then
		return false
	end

	if vim.fn.filereadable(file) ~= 1 then
		vim.notify("File not found: " .. file, vim.log.levels.ERROR)
		return false
	end

	lnum = tonumber(lnum)
	col = tonumber(col)

	local bufnr = vim.fn.bufnr(vim.fn.fnamemodify(file, ":p"))
	local win_id = nil

	if bufnr ~= -1 then
		local wins = vim.fn.getbufinfo(bufnr)[1].windows
		if #wins > 0 then
			win_id = wins[1]
		end
	end

	if win_id then
		vim.fn.win_gotoid(win_id)
	else
		local window_above = vim.fn.winnr("#")

		if window_above ~= 0 then
			vim.cmd("wincmd k")
			vim.cmd("edit " .. file)
		else
			vim.cmd("topleft split " .. file)
		end
	end

	vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
	vim.cmd("normal! zz")

	return true
end

return M
