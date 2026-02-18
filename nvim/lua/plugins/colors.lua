return {
    {
        "https://github.com/p00f/alabaster.nvim",
    },
    {
        "morhetz/gruvbox",
        config = function()
            vim.g.gruvbox_contrast_dark = "hard"
            vim.g.gruvbox_sign_column = "bg0"
            vim.g.gruvbox_italicize_comments = 0
            vim.g.gruvbox_invert_selection = 1
        end,
    },
    { "https://github.com/sainnhe/sonokai" },
    {
        "sainnhe/gruvbox-material",
        config = function()
            vim.g.gruvbox_material_disable_italic_comment = 1
            vim.g.gruvbox_material_enable_italic = 0
            vim.g.gruvbox_material_enable_bold = 0
            vim.g.gruvbox_material_transparent_background = 1
            vim.g.gruvbox_material_better_performance = 1
            vim.g.gruvbox_material_foreground = "material"
        end,
    },
    {
        "rose-pine/neovim",
        name = "rose-pine",
    },
    {
        "rktjmp/lush.nvim",
        lazy = false,
    },
}
