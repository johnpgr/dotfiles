-- Autocmds and filetype registrations

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Detect image files and set filetype
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
	callback = function()
		vim.bo.filetype = "image"
	end,
})

-- Advertise this Neovim server to WezTerm so clicked diagnostics can target
-- the editor pane in the current tab without a terminal output proxy.
do
	local group = vim.api.nvim_create_augroup("WezTermOpenInNvim", { clear = true })
	local state_dir = vim.fn.stdpath("state") .. "/wezterm-open-in-nvim"
	local registry_file = state_dir .. "/" .. vim.fn.getpid() .. ".server"

	local function ensure_server()
		if vim.v.servername ~= nil and vim.v.servername ~= "" then
			return vim.v.servername
		end

		local ok, server = pcall(vim.fn.serverstart)
		if ok then
			return server
		end

		return nil
	end

	local function write_registry()
		local server = ensure_server()
		if server == nil or server == "" then
			return
		end

		pcall(vim.fn.mkdir, state_dir, "p")
		pcall(vim.fn.writefile, { server, vim.fn.getcwd() }, registry_file)
	end

	local function remove_registry()
		pcall(vim.fn.delete, registry_file)
	end

	vim.api.nvim_create_user_command("WezTermOpenInNvimDebug", function()
		write_registry()
		print(registry_file)
		print(table.concat(vim.fn.readfile(registry_file), "\n"))
	end, {})

	vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged", "FocusGained", "BufEnter" }, {
		group = group,
		callback = write_registry,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = remove_registry,
	})
end

-- LSP document highlight on cursor hold
-- vim.api.nvim_create_autocmd("LspAttach", {
-- 	group = vim.api.nvim_create_augroup("lsp-document-highlight", { clear = true }),
-- 	callback = function(event)
-- 		local client = vim.lsp.get_client_by_id(event.data.client_id)
-- 		if client and client:supports_method("textDocument/documentHighlight", event.buf) then
-- 			local augroup = vim.api.nvim_create_augroup("lsp-document-highlight-" .. event.buf, { clear = false })
-- 			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
-- 				buffer = event.buf,
-- 				group = augroup,
-- 				callback = vim.lsp.buf.document_highlight,
-- 			})
-- 			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
-- 				buffer = event.buf,
-- 				group = augroup,
-- 				callback = vim.lsp.buf.clear_references,
-- 			})
-- 			vim.api.nvim_create_autocmd("LspDetach", {
-- 				group = vim.api.nvim_create_augroup("lsp-document-highlight-detach-" .. event.buf, { clear = true }),
-- 				buffer = event.buf,
-- 				callback = function(event2)
-- 					vim.lsp.buf.clear_references()
-- 					vim.api.nvim_clear_autocmds({ group = augroup, buffer = event2.buf })
-- 				end,
-- 			})
-- 		end
-- 	end,
-- })

-- Custom filetypes
vim.filetype.add({
	extension = {
		hlsl = "hlsl",
		m = "objc",
	},
})
