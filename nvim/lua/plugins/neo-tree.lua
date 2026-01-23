return {
    {
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
                "<leader>e",
                function()
                    local reveal_file = vim.fn.expand("%:p")
                    if reveal_file == "" then
                        reveal_file = vim.fn.getcwd()
                    else
                        local f = io.open(reveal_file, "r")
                        if f then
                            f:close()
                        else
                            reveal_file = vim.fn.getcwd()
                        end
                    end

                    require("neo-tree.command").execute({
                        action = "focus",
                        source = "filesystem",
                        position = "left",
                        toggle = true,
                        reveal_file = reveal_file,
                        reveal_force_cwd = true,
                    })
                end,
                desc = "Explorer",
            },
        },
        config = function()
            local opts = {
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
    },
}
