-- General plugins
return {
    -- Dependency plugins (loaded by other plugins)
    {
        "kkharji/sqlite.lua",
        lazy = false,
    },
    {
        "nvim-lua/plenary.nvim",
        lazy = true,
    },
    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
        cond = vim.g.icons_enabled,
    },
    {
        "nvim-mini/mini.bufremove",
        config = function()
            require("mini.bufremove").setup {}
        end,
        keys = {
            {
                "<leader>bd",
                function()
                    require("mini.bufremove").delete()
                end,
                desc = "Buffer delete",
            },
        }
    },
    -- Colorschemes
    {
        "morhetz/gruvbox",
        lazy = false,
        priority = 1000,
    },
    {
        "vague2k/vague.nvim",
        config = function()
            require("vague").setup({
                bold = false,
                italic = false,
            })
        end
    },
    {
        "rose-pine/neovim",
        name = "rosepine",
        lazy = false,
        priority = 1000,
        config = function()
            require("rose-pine").setup({
                styles = {
                    bold = false,
                    italic = false,
                    transparency = true,
                },
            })
        end,
    },
    {
        "navarasu/onedark.nvim",
        config = function()
            require('onedark').setup {
                code_style = {
                    comments = 'none',
                    keywords = 'none',
                    functions = 'none',
                    strings = 'none',
                    variables = 'none'
                },
            }
        end
    },
    -- Session management
    { "farmergreg/vim-lastplace", event = "BufReadPre" },
    -- UI enhancements
    { "mbbill/undotree",          cmd = "UndotreeToggle" },
    { "hedyhli/outline.nvim",     cmd = "Outline" },
    {
        "mg979/vim-visual-multi",
        event = "BufReadPost",
        config = function()
            vim.cmd([[
                let g:VM_maps = {}
                let g:VM_maps["Goto Prev"] = "\[\["
                let g:VM_maps["Goto Next"] = "\]\]"
                nmap <C-M-n> <Plug>(VM-Select-All)
            ]])
        end,
    },
    -- Text manipulation
    {
        "johmsalas/text-case.nvim",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("textcase").setup({
                prefix = "tc",
            })
        end,
    },
    { "tpope/vim-abolish" },
    -- Indent guides
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("ibl").setup({
                indent = { char = "│" },
                enabled = false,
                scope = { enabled = false },
            })
        end,
    },
}
