-- Git: gitsigns, fugitive

return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				attach_to_untracked = true,
				preview_config = {
					border = "single",
					focusable = false,
				},
			})
		end,
	},

	{
		"tpope/vim-fugitive",
		lazy = false,
		cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gclog" },
		keys = {
			{ "<M-g>", "<cmd>Git<cr>", desc = "Git status" },
			{ "<leader>gg", "<cmd>Git<cr>", desc = "Git status" },
			{ "<leader>gc", "<cmd>Git commit<cr>", desc = "Git commit" },
			{ "<leader>gb", "<cmd>Git branch<cr>", desc = "Git branch" },
			{ "<leader>gl", "<cmd>Git log<cr>", desc = "Git log" },
			{ "<leader>gd", "<cmd>Gvdiffsplit<cr>", desc = "Git diff split" },
			{ "<leader>gD", ":Gdiffsplit ", desc = "Git diff split (Revision)" },
			{
				"<leader>gh",
				function()
					vim.cmd("0Gclog")
					vim.cmd("copen")
				end,
				desc = "Git file history (Current)",
			},
			{ "<leader>gH", "<cmd>Git log<cr>", desc = "Git file history (All)" },
		},
		config = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "fugitive",
				callback = function()
					vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
					vim.keymap.set("n", "<Tab>", "=", { buffer = true, remap = true })
					vim.bo.buflisted = false
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "gitcommit",
				callback = function()
					vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
					vim.bo.buflisted = false
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "git",
				callback = function()
					vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
					vim.bo.buflisted = false
				end,
			})
		end,
	},
}
