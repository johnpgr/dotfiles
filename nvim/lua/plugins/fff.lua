return {
    "dmtrKovalenko/fff.nvim",
    lazy = true,
    build = function()
        require("fff.download").download_or_build_binary()
    end,
}
