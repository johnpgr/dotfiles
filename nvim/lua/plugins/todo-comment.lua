return {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
        highlight = {
            before = "",
            keyword = "fg",
            after = "fg",
        },
        keywords = {
            TODO = { color = "todo" },
        },
        colors = {
            todo = { "Added", "DiffAdd", "#03CF0C" },
        },
    },
    config = function(_, opts)
        require("todo-comments").setup(opts)

        local group = vim.api.nvim_create_augroup("TodoCommentsFgOnly", { clear = true })

        local function relink_background_groups()
            local ok, config = pcall(require, "todo-comments.config")
            if not ok or not config.options or not config.options.keywords then
                return
            end

            local keywords = config.options.keywords
            for keyword, _ in pairs(keywords) do
                vim.api.nvim_set_hl(0, "TodoBg" .. keyword, { link = "TodoFg" .. keyword })
            end
        end

        vim.defer_fn(relink_background_groups, 20)
        vim.api.nvim_create_autocmd("VimEnter", {
            group = group,
            once = true,
            callback = function()
                vim.defer_fn(relink_background_groups, 20)
            end,
        })
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            callback = function()
                vim.defer_fn(relink_background_groups, 20)
            end,
        })
    end,
}
