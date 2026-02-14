return {
    enabled = true,
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        { "nvim-tree/nvim-web-devicons", cond = vim.g.icons_enabled },
    },
    lazy = false, -- neo-tree will lazily load itself
    keys = {
        {
            "<leader>b",
            "<cmd>Neotree toggle<cr>",
            desc = "Sidebar (Neo-tree)",
        },
    },
    config = function()
        local opts = {
            window = {
                position = "left",
                width = 30,
                mapping_options = {
                    noremap = true,
                    nowait = true,
                },
            },
            enable_git_status = false,
            enable_diagnostics = false,
            filesystem = {
                follow_current_file = {
                    enabled = true,
                    leave_dirs_open = false,
                },
            },
        }

        if not vim.g.icons_enabled then
            opts.default_component_configs = {
                indent = {
                    with_expanders = true,
                    expander_collapsed = ">",
                    expander_expanded = "v",
                },
            }

            -- Drop the file/folder icon component entirely (no extra padding)
            opts.renderers = {
                directory = {
                    { "indent" },
                    { "name" },
                },
                file = {
                    { "indent" },
                    { "name" },
                },
            }
        end

        require("neo-tree").setup(opts)
    end,
}
