require("options")
require("statusline")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Load lazy.nvim with plugins
require("lazy").setup("plugins", {
    ui = {
        border = "single",
    },
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

-- Filetype additions
vim.filetype.add({
    extension = {
        hlsl = "hlsl",
        m = "objc",
    },
})

-- -- Only on nightly
if vim.version().minor >= 12 then
    require("vim._core.ui2").enable({})
end

require("autocmds")
require("keymaps")
require("cmdline")

if require("utils").is_neovide then
    require("neovide")
end
