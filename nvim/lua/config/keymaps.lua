-- Keymaps
-- Picker keymaps are in config/picker.lua
-- Plugin-specific keymaps that need a plugin loaded are defined inside the plugin's config

-- EditorConfig template (used by <leader>ie)
local editorconfig = [[
# EditorConfig is awesome: https://editorconfig.org

# top-most EditorConfig file
root = true

# Unix-style newlines with a newline ending every file
[*]
end_of_line = lf
insert_final_newline = true

# Matches multiple files with brace expansion notation
# Set default charset
[*.{js,py}]
charset = utf-8

# 4 space indentation
[*.py]
indent_style = space
indent_size = 4

# Tab indentation (no size specified)
[Makefile]
indent_style = tab

# Indentation override for all JS under lib directory
[lib/**.js]
indent_style = space
indent_size = 2

# Matches the exact files either package.json or .travis.yml
[{package.json,.travis.yml}]
indent_style = space
indent_size = 2
]]

-- --------------------------------------------------------------------------
-- Navigation
-- --------------------------------------------------------------------------
vim.keymap.set("n", "<leader>w", "<cmd>update<cr>", { desc = "Write" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>re", "<cmd>restart<cr>", { desc = "Restart" })
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
vim.keymap.set("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlights" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>I", "<cmd>Inspect<cr>", { desc = "Inspect" })
vim.keymap.set("n", "yig", ":%y<CR>", { desc = "Yank buffer" })
vim.keymap.set("n", "vig", "ggVG", { desc = "Visual select buffer" })
vim.keymap.set("n", "cig", ":%d<CR>i", { desc = "Change buffer" }) vim.keymap.set("n", "n", "nzz", { desc = "Next search result" }) vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Previous diagnostic" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("v", "<", "<gv", { desc = "Decrease indent" })
vim.keymap.set("v", ">", ">gv", { desc = "Increase indent" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })

---@param count number
local function transpose_words(count)
	if count == 0 then
		return
	end

	local direction = count > 0 and 1 or -1

	for _ = 1, math.abs(count) do
		local line = vim.api.nvim_get_current_line()
		local mode = vim.api.nvim_get_mode().mode
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local boundary = col
		local spans = {}

		for start_col, end_col in line:gmatch("()[%w_]+()") do
			spans[#spans + 1] = {
				start_col = start_col - 1,
				end_col = end_col - 1,
			}
		end

		local current_index
		for index, span in ipairs(spans) do
			if span.start_col <= boundary and boundary <= span.end_col then
				current_index = index
				break
			end
		end

		if not current_index then
			return
		end

		local target_index = current_index + direction
		local current = spans[current_index]
		local target = spans[target_index]

		if not target then
			return
		end

		local first = direction > 0 and current or target
		local second = direction > 0 and target or current
		local before = line:sub(1, first.start_col)
		local first_word = line:sub(first.start_col + 1, first.end_col)
		local middle = line:sub(first.end_col + 1, second.start_col)
		local second_word = line:sub(second.start_col + 1, second.end_col)
		local after = line:sub(second.end_col + 1)
		local moved_start_col = direction > 0 and (#before + #second_word + #middle) or #before
		local moved_word = direction > 0 and first_word or second_word
		local new_col = moved_start_col + #moved_word

		vim.api.nvim_set_current_line(before .. second_word .. middle .. first_word .. after)

		if mode:sub(1, 1) == "i" then
			vim.api.nvim_win_set_cursor(0, { row, new_col })
		else
			vim.api.nvim_win_set_cursor(0, { row, math.max(new_col - 1, 0) })
		end
	end
end

vim.keymap.set({ "n", "i" }, "<M-,>", function()
	transpose_words(-1)
end, { desc = "Transpose words backward" })

vim.keymap.set({ "n", "i" }, "<M-.>", function()
	transpose_words(1)
end, { desc = "Transpose words forward" })


-- --------------------------------------------------------------------------
-- Toggle keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<leader>tl", function()
	if vim.o.number and vim.o.relativenumber then
		vim.o.relativenumber = false
	elseif vim.o.number and not vim.o.relativenumber then
		vim.o.number = false
	else
		vim.o.number = true
		vim.o.relativenumber = true
	end
end, { desc = "Line numbers" })

vim.keymap.set("n", "<leader>tI", function()
	if vim.o.expandtab then
		vim.o.expandtab = false
		vim.notify("Indent style: tabs", vim.log.levels.INFO)
	else
		vim.o.expandtab = true
		vim.notify("Indent style: spaces", vim.log.levels.INFO)
	end
end, { desc = "Indent style" })

vim.keymap.set("n", "<leader>ts", function()
	if vim.o.signcolumn == "no" then
		vim.o.signcolumn = "yes"
	else
		vim.o.signcolumn = "no"
	end
end, { desc = "Sign column" })

vim.keymap.set("n", "<leader>td", function()
	if vim.diagnostic.is_enabled() then
		vim.diagnostic.enable(false)
		vim.notify("Diagnostics disabled", vim.log.levels.INFO)
	else
		vim.diagnostic.enable(true)
		vim.notify("Diagnostics enabled", vim.log.levels.INFO)
	end
end, { desc = "Diagnostics" })

-- --------------------------------------------------------------------------
-- Yank keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<leader>fy", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	vim.fn.setreg("+", filepath)
	print("Copied path: " .. filepath)
end, { desc = "Yank filepath" })

vim.keymap.set("n", "<leader>fY", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	local relative_path = vim.fn.fnamemodify(filepath, ":~:.")
	vim.fn.setreg("+", relative_path)
	print("Copied path: " .. relative_path)
end, { desc = "Yank filepath from workspace" })

vim.keymap.set("n", "<leader>tt", function()
	vim.g.treesitter_enabled = not vim.g.treesitter_enabled
	if not vim.g.treesitter_enabled then
		vim.treesitter.stop()
		vim.notify("Treesitter disabled (except markdown)", vim.log.levels.INFO)
	else
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			local ft = vim.bo[bufnr].filetype
			if ft ~= "" and ft ~= "markdown" then
				pcall(vim.treesitter.start, bufnr, ft)
			end
		end
		vim.notify("Treesitter enabled", vim.log.levels.INFO)
	end
end, { desc = "Toggle treesitter" })

-- --------------------------------------------------------------------------
-- Insert keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<leader>if", function()
	local filename = vim.fn.expand("%:t")
	if filename == "" then
		return
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. filename .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filename })
end, { desc = "File name" })

vim.keymap.set("n", "<leader>iF", function()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. filepath .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filepath })
end, { desc = "File path" })

vim.keymap.set("n", "<leader>ie", function()
	local editor_config = editorconfig
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1 -- 0-indexed
	local lines = vim.split(editor_config, "\n", { plain = true })
	vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
	if #lines == 1 then
		vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
	else
		vim.api.nvim_win_set_cursor(0, { row + #lines, #lines[#lines] })
	end
end, { desc = "Editorconfig" })

-- --------------------------------------------------------------------------
-- LSP keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })
vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Goto references" })
vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>lf", function()
	require("conform").format({ async = true })
end, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Diagnostic" })
vim.keymap.set("n", "<leader>ll", vim.diagnostic.setqflist, { desc = "Diagnostic List" })

-- --------------------------------------------------------------------------
-- Quickfix keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "]c", function()
	local qf_list = vim.fn.getqflist()
	local qf_length = #qf_list
	if qf_length == 0 then
		return
	end

	local current_idx = vim.fn.getqflist({ idx = 0 }).idx
	if current_idx >= qf_length then
		vim.cmd("cfirst")
	else
		vim.cmd("cnext")
	end
	vim.cmd("copen")
end, { desc = "Next quickfix item" })

vim.keymap.set("n", "[c", function()
	local qf_list = vim.fn.getqflist()
	local qf_length = #qf_list
	if qf_length == 0 then
		return
	end

	local current_idx = vim.fn.getqflist({ idx = 0 }).idx
	if current_idx <= 1 then
		vim.cmd("clast")
	else
		vim.cmd("cprevious")
	end
	vim.cmd("copen")
end, { desc = "Previous quickfix item" })

-- --------------------------------------------------------------------------
-- Compile keymaps
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<leader>m", "<cmd>Compile<cr>", { desc = "Compile" })

-- --------------------------------------------------------------------------
-- Git / hunk keymaps (requires gitsigns)
-- --------------------------------------------------------------------------

local function nav_hunk(direction)
	if vim.wo.diff then
		local key = direction == "next" and "]c" or "[c"
		vim.cmd.normal({ key, bang = true })
		return
	end

	local popup = require("gitsigns.popup")
	popup.close("hunk")

	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.api.nvim_win_get_config(w).relative == "" then
				vim.api.nvim_set_current_win(w)
				break
			end
		end
	end

	local gitsigns = require("gitsigns")
	local bufnr = vim.api.nvim_get_current_buf()
	local hunks = gitsigns.get_hunks(bufnr) or {}
	if #hunks == 0 then
		return
	end

	local cur = vim.api.nvim_win_get_cursor(0)[1]
	local target

	if direction == "next" then
		for _, h in ipairs(hunks) do
			if h.added.start > cur then
				target = h.added.start
				break
			end
		end
		if not target then
			target = hunks[1].added.start
		end
	else
		for i = #hunks, 1, -1 do
			if hunks[i].added.start < cur then
				target = hunks[i].added.start
				break
			end
		end if not target then target = hunks[#hunks].added.start
		end
	end

	target = math.max(1, math.min(target, vim.api.nvim_buf_line_count(bufnr)))
	vim.api.nvim_win_set_cursor(0, { target, 0 })

	vim.schedule(function()
		gitsigns.preview_hunk()
	end)
end

vim.keymap.set("n", "]h", function()
	nav_hunk("next")
end, { desc = "Next hunk" })
vim.keymap.set("n", "[h", function()
	nav_hunk("prev")
end, { desc = "Previous hunk" })
vim.keymap.set("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>gB", "<cmd>Gitsigns blame<cr>", { desc = "Git blame" })
vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
vim.keymap.set("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame inline" })
vim.keymap.set("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", { desc = "Preview hunk inline" })
vim.keymap.set("n", "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", { desc = "Toggle word diff" })

vim.keymap.set("n", "<leader>tu", function()
	vim.cmd.packadd("nvim.undotree")
	vim.cmd.Undotree()
end, { desc = "Undotree" })

-- --------------------------------------------------------------------------
-- Window management (tmux.nvim + builtin)
-- --------------------------------------------------------------------------

vim.keymap.set("n", "<C-h>", function()
	require("tmux").move_left()
end, { desc = "Focus split left" })
vim.keymap.set("n", "<C-j>", function()
	require("tmux").move_bottom()
end, { desc = "Focus split down" })
vim.keymap.set("n", "<C-k>", function()
	require("tmux").move_top()
end, { desc = "Focus split up" })
vim.keymap.set("n", "<C-l>", function()
	require("tmux").move_right()
end, { desc = "Focus split right" })

vim.keymap.set("n", "<M-h>", function()
	require("tmux").resize_left()
end, { desc = "Resize split left" })
vim.keymap.set("n", "<M-j>", function()
	require("tmux").resize_bottom()
end, { desc = "Resize split down" })
vim.keymap.set("n", "<M-k>", function()
	require("tmux").resize_top()
end, { desc = "Resize split up" })
vim.keymap.set("n", "<M-l>", function()
	require("tmux").resize_right()
end, { desc = "Resize split right" })

vim.keymap.set("n", "<leader>z", "<C-w>_<C-w>|", { desc = "Maximize window" })

-- --------------------------------------------------------------------------
-- Misc plugin keymaps
-- --------------------------------------------------------------------------
vim.keymap.set("n", "<leader>E", "<cmd>Oil<cr>", {desc = "Explore"})

vim.keymap.set("n", "<leader>e", function()
	if vim.bo.filetype == "oil" then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local is_empty = vim.api.nvim_buf_get_name(buf) == ""
		and vim.bo.buftype == ""
		and not vim.bo.modified
		and vim.api.nvim_buf_line_count(buf) == 1
		and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
	if not is_empty then
		vim.cmd("belowright split")
	end
	vim.cmd("Oil")
end, { desc = "Explore" })
vim.keymap.set("n", "<leader>c", function()
	require("quicker").toggle()
end, { desc = "Quickfix list" })

-- --------------------------------------------------------------------------
-- Neovide
-- --------------------------------------------------------------------------

if vim.g.neovide then
	vim.keymap.set("n", "<C-=>", function()
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * 1.1
	end, { desc = "Increase Neovide scale factor" })

	vim.keymap.set("n", "<C-->", function()
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor / 1.1
	end, { desc = "Decrease Neovide scale factor" })

	local function paste_clipboard()
		-- Terminal-mode Ctrl-R is interpreted by the terminal, so use Neovim's paste API instead.
		vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
	end

	vim.keymap.set("v", "<C-S-c>", '"+y', { desc = "Copy clipboard" })
	vim.keymap.set("n", "<C-S-v>", '"+P', { desc = "Paste clipboard" })
	vim.keymap.set("v", "<C-S-v>", '"+P', { desc = "Paste clipboard" })
	vim.keymap.set("c", "<C-S-v>", "<C-R>+", { desc = "Paste clipboard" })
	vim.keymap.set({ "i", "t" }, "<C-S-v>", paste_clipboard, { desc = "Paste clipboard" })
end
