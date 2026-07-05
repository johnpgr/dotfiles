-- Buffer picker + native-cmdline picker keymaps
-- File finding via :find is in config/find.lua
-- Grep via fff → quickfix is in config/grep.lua

function _G.dotfiles_buffer_completion(arg_lead)
	local items = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
			if buftype == "" then
				local name = vim.api.nvim_buf_get_name(bufnr)
				if name and name ~= "" then
					table.insert(items, vim.fn.fnamemodify(name, ":."))
				end
			end
		end
	end

	if arg_lead == "" then
		return items
	end

	local matches = {}
	local needle = arg_lead:lower()
	for _, item in ipairs(items) do
		if item:lower():find(needle, 1, true) then
			table.insert(matches, item)
		end
	end

	return vim.tbl_isempty(matches) and items or matches
end

---Open buffer picker with input() + customlist completion.
local function open_buffer_picker()
	vim.fn.inputsave()
	vim.defer_fn(function()
		vim.api.nvim_input("<Tab><Tab>")
	end, 10)

	local buf_str = vim.fn.input("Buffers > ", "", "customlist,v:lua.dotfiles_buffer_completion")
	vim.fn.inputrestore()
	if not buf_str or buf_str == "" then
		return
	end

	local bufnr = vim.fn.bufnr(buf_str)
	if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
		vim.notify("Invalid buffer: " .. buf_str, vim.log.levels.WARN)
		return
	end

	vim.api.nvim_set_current_buf(bufnr)
end

-- Buffer picker
vim.keymap.set("n", "<leader>,", open_buffer_picker, { desc = "Buffers" })

-- Secondary pickers replaced by native cmdline with tab-completion
vim.keymap.set("n", "<leader>sc", function()
	vim.api.nvim_feedkeys(":colorscheme ", "n", false)
end, { desc = "Search colorscheme" })

vim.keymap.set("n", "<leader>so", function()
	vim.api.nvim_feedkeys(":set ", "n", false)
end, { desc = "Search option" })

vim.keymap.set("n", "<leader>sH", function()
	vim.api.nvim_feedkeys(":highlight ", "n", false)
end, { desc = "Search highlight group" })

vim.keymap.set("n", "<leader>sh", function()
	vim.api.nvim_feedkeys(":help ", "n", false)
end, { desc = "Search help" })

vim.keymap.set("n", "<M-x>", function()
	vim.api.nvim_feedkeys(":command ", "n", false)
end, { desc = "Commands" })
