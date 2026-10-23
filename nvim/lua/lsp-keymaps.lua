local mappings = {
	{ "gd", vim.lsp.buf.definition, "textDocument/definition", "LSP definition" },
	{ "gD", vim.lsp.buf.declaration, "textDocument/declaration", "LSP declaration" },
	{ "gr", vim.lsp.buf.references, "textDocument/references", "LSP references" },
	{ "gi", vim.lsp.buf.implementation, "textDocument/implementation", "LSP implementation" },
	{ "gy", vim.lsp.buf.type_definition, "textDocument/typeDefinition", "LSP type definition" },
	{ "K", vim.lsp.buf.hover, "textDocument/hover", "LSP hover documentation" },
	{ "gK", vim.lsp.buf.signature_help, "textDocument/signatureHelp", "LSP signature help" },
	{ "<leader>rn", vim.lsp.buf.rename, "textDocument/rename", "LSP rename symbol" },
	{ "<leader>ca", vim.lsp.buf.code_action, "textDocument/codeAction", "LSP code action", { "n", "x" } },
	{ "<leader>lf", vim.lsp.buf.format, "textDocument/formatting", "LSP format buffer" },
	{ "<leader>ls", vim.lsp.buf.document_symbol, "textDocument/documentSymbol", "LSP document symbols" },
	{ "<leader>lS", vim.lsp.buf.workspace_symbol, "workspace/symbol", "LSP workspace symbols" },
}

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
	group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
	callback = function(event)
		local clients = vim.lsp.get_clients({ bufnr = event.buf })
		for _, mapping in ipairs(mappings) do
			local key, action, method, description, modes = unpack(mapping)
			local supported = false
			for _, client in ipairs(clients) do
				-- LspDetach fires before the client is removed from the buffer.
				if not (event.event == "LspDetach" and client.id == event.data.client_id)
					and client:supports_method(method, event.buf) then
					supported = true
					break
				end
			end

			if supported then
				vim.keymap.set(modes or "n", key, action, { buffer = event.buf, desc = description })
			else
				vim.api.nvim_buf_call(event.buf, function()
					for _, mode in ipairs(modes or { "n" }) do
						local existing = vim.fn.maparg(key, mode, false, true)
						if existing.buffer == 1 and existing.desc == description then
							vim.keymap.del(mode, key, { buffer = event.buf })
						end
					end
				end)
			end
		end
	end,
})

vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show line diagnostics" })
vim.keymap.set("n", "<leader>ld", vim.diagnostic.setloclist, { desc = "Buffer diagnostics list" })
