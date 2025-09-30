-- Clipboard setup
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	once = true,
	callback = function()
		if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
			vim.g.clipboard = {
				copy = {
					["+"] = "win32yank.exe -i --crlf",
					["*"] = "win32yank.exe -i --crlf",
				},
				paste = {
					["+"] = "win32yank.exe -o --lf",
					["*"] = "win32yank.exe -o --lf",
				},
			}
		elseif vim.fn.has("unix") == 1 then
			if vim.fn.executable("xclip") == 1 then
				vim.g.clipboard = {
					copy = {
						["+"] = "xclip -selection clipboard",
						["*"] = "xclip -selection clipboard",
					},
					paste = {
						["+"] = "xclip -selection clipboard -o",
						["*"] = "xclip -selection clipboard -o",
					},
				}
			elseif vim.fn.executable("xsel") == 1 then
				vim.g.clipboard = {
					copy = {
						["+"] = "xsel --clipboard --input",
						["*"] = "xsel --clipboard --input",
					},
					paste = {
						["+"] = "xsel --clipboard --output",
						["*"] = "xsel --clipboard --output",
					},
				}
			end
		end
		vim.opt.clipboard = "unnamedplus"
	end,
	desc = "Slow clipboard fix",
})

-- LSP attach autocmd
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		---@diagnostic disable-next-line: need-check-nil
		client.server_capabilities.semanticTokensProvider = nil
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	callback = require("colorscheme").load_persisted_colorscheme,
	once = true,
})

local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	group = highlight_group,
	callback = function()
		vim.highlight.on_yank()

		-- Save to database
		local content = vim.fn.getreg('"')
		if content and content ~= "" then
			pcall(function()
				require("yank").db.entries:add(content)
			end)
		end
	end,
	pattern = "*",
})
