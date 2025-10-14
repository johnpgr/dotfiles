-- Overseer.nvim
return {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerQuickAction" },
    keys = {
        { "<leader>bt", "<cmd>OverseerRun<cr>", desc = "Run build task" },
        { "<leader>tt", "<cmd>OverseerToggle bottom<cr>", desc = "Build tasks" },
        { "<A-r>", "<cmd>OverseerQuickAction restart<cr>", desc = "Restart last task" },
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
