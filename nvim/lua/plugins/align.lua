return {
    "nvim-mini/mini.align",
    version = "*",
    config = function()
        require("mini.align").setup({
            mappings = {
                start = "ga",
                start_with_preview = "gA",
            },
        })
    end,
}
