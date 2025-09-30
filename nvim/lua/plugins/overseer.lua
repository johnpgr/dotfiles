-- Overseer.nvim
return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerRun", "OverseerToggle", "OverseerQuickAction" },
	keys = {
		{ "<F1>", "<cmd>OverseerRun<cr>", desc = "Run task" },
		{ "<F2>", "<cmd>OverseerToggle bottom<cr>", desc = "Task list (bottom)" },
		{ "<F3>", "<cmd>OverseerToggle right<cr>", desc = "Task list (right)" },
		{ "<A-r>", "<cmd>OverseerQuickAction restart<cr>", desc = "Restart last task" },
		{ "<F5>", "<cmd>OverseerQuickAction restart<cr>", desc = "Restart last task" },
	},
	config = function()
		require("overseer").setup({
			task_list = {
				min_width = { 60, 0.25 },
				bindings = {
					["R"] = "<cmd>OverseerQuickAction restart<cr>",
					["D"] = "<cmd>OverseerQuickAction dispose<cr>",
					["W"] = "<cmd>OverseerQuickAction watch<cr>",
					["S"] = "<cmd>OverseerQuickAction stop<cr>",
					["<C-l>"] = false,
					["<C-h>"] = false,
					["<C-k>"] = false,
					["<C-j>"] = false,
				},
			},
		})
	end,
}
