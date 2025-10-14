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
            require("mini.bufremove").setup({})
        end,
        keys = {
            {
                "<leader>bd",
                function()
                    require("mini.bufremove").delete()
                end,
                desc = "Buffer delete",
            },
        },
    },
    -- Colorschemes
    {
        "sainnhe/sonokai",
        config = function()
            vim.g.sonokai_transparent_background = 1
            vim.g.sonokai_enable_italic = 0
            vim.g.sonokai_disable_italic_comment = 1
            -- vim.g.sonokai_style = "espresso"
        end,
    },
    -- {
    --     "morhetz/gruvbox",
    --     lazy = false,
    --     priority = 1000,
    -- },
    -- {
    --     "rose-pine/neovim",
    --     name = "rosepine",
    --     lazy = false,
    --     priority = 1000,
    --     config = function()
    --         require("rose-pine").setup({
    --             styles = {
    --                 bold = false,
    --                 italic = false,
    --                 transparency = true,
    --             },
    --         })
    --     end,
    -- },
    -- {
    --     "navarasu/onedark.nvim",
    --     config = function()
    --         require('onedark').setup {
    --             style = 'warm', -- Default theme style. Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer' and 'light'
    --             code_style = {
    --                 comments = 'none',
    --                 keywords = 'none',
    --                 functions = 'none',
    --                 strings = 'none',
    --                 variables = 'none'
    --             },
    --         }
    --     end
    -- },
    -- { 'datsfilipe/vesper.nvim',
    --     config = function ()
    --         require('vesper').setup({
    --             transparent = false, -- Boolean: Sets the background to transparent
    --             italics = {
    --                 comments = false, -- Boolean: Italicizes comments
    --                 keywords = false, -- Boolean: Italicizes keywords
    --                 functions = false, -- Boolean: Italicizes functions
    --                 strings = false, -- Boolean: Italicizes strings
    --                 variables = false, -- Boolean: Italicizes variables
    --             },
    --             overrides = {}, -- A dictionary of group names, can be a function returning a dictionary or a table.
    --             palette_overrides = {}
    --         })
    --     end
    -- },
    -- Session management
    { "farmergreg/vim-lastplace", event = "BufReadPre" },
    -- UI enhancements
    {
        "mbbill/undotree",
        cmd = "UndotreeToggle",
        keys = {
            { "<leader>tu", "<cmd>UndotreeToggle<cr>", desc = "Undotree" },
        },
    },

    {
        "hedyhli/outline.nvim",
        lazy = true,
        cmd = { "Outline", "OutlineOpen" },
        keys = {
            { "<leader>to", "<cmd>Outline<CR>", desc = "Toggle outline" },
        },
        opts = {},
    },
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
    {
        event = { "BufReadPost", "BufNewFile" },
        "tpope/vim-abolish",
    },
    -- Indent guides
    {
        "lukas-reineke/indent-blankline.nvim",
        cmd = "IBLToggle",
        keys = { { "<leader>ti", "<cmd>IBLToggle<cr>", desc = "Indent guides" } },
        config = function()
            require("ibl").setup({
                indent = { char = "│" },
                enabled = false,
                scope = { enabled = false },
            })
        end,
    },
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        build = "cd app && npm install",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
        ft = { "markdown" },
    },
}
