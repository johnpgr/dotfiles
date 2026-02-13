-- Blink completion
return {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = {
        "L3MON4D3/LuaSnip",
        "rafamadriz/friendly-snippets",
        "xzbdmw/colorful-menu.nvim",
    },
    version = "1.*",
    config = function()
        local function has_words_before()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            if col == 0 then
                return false
            end
            local line = vim.api.nvim_get_current_line()
            return line:sub(col, col):match("%s") == nil
        end

        local function toggle_menu(cmp)
            if not require("blink.cmp").is_visible() then
                cmp.show()
            else
                cmp.hide()
            end
        end

        -- Custom insert_next without can_select check
        local function custom_insert_next(cmp)
            if not cmp.is_active() then
                return cmp.show_and_insert()
            end
            -- if not require('blink.cmp.completion.list').can_select({ auto_insert = true }) then return end
            vim.schedule(function()
                require("blink.cmp.completion.list").select_next({ auto_insert = true })
            end)
            return true
        end

        -- Custom insert_prev without can_select check
        local function custom_insert_prev(cmp)
            if not cmp.is_active() then
                return cmp.show_and_insert()
            end
            -- if not require('blink.cmp.completion.list').can_select({ auto_insert = true }) then return end
            vim.schedule(function()
                require("blink.cmp.completion.list").select_prev({ auto_insert = true })
            end)
            return true
        end

        local function emacs_tab(cmp)
            if require("blink.cmp").is_visible() then
                return cmp.select_and_accept()
            elseif has_words_before() then
                return custom_insert_next(cmp)
            end
        end

        local function accept_copilot_suggestion()
            local ok, copilot_suggestion = pcall(require, "copilot.suggestion")
            if not ok or not copilot_suggestion.is_visible() then
                return false
            end

            copilot_suggestion.accept()
            return true
        end

        local function tab_action(cmp)
            if vim.g.emacs_tab == true then
                return emacs_tab(cmp)
            end

            if accept_copilot_suggestion() then
                return true
            end

            if require("blink.cmp").is_visible() then
                return cmp.accept()
            end
        end

        local columns = {}

        if not vim.g.icons_enabled then
            columns = { { "label", gap = 1 }, { "source_name" } }
        else
            columns = { { "kind_icon" }, { "label", gap = 1 }, { "source_name" } }
        end

        require("blink.cmp").setup({
            appearance = {
                kind_icons = {
                    Text = "",
                    Method = "",
                    Function = "",
                    Constructor = "",
                    Field = "",
                    Variable = "",
                    Class = "",
                    Interface = "",
                    Module = "",
                    Property = "",
                    Unit = "",
                    Value = "",
                    Enum = "",
                    Keyword = "",
                    Snippet = "",
                    Color = "",
                    File = "",
                    Reference = "",
                    Folder = "",
                    EnumMember = "",
                    Constant = "",
                    Struct = "",
                    Event = "",
                    Operator = "",
                    TypeParameter = "",
                },
            },
            keymap = {
                preset = "none",
                ["<C-space>"] = { toggle_menu },
                ["<CR>"] = {
                    "fallback",
                },
                ["<Tab>"] = {
                    tab_action,
                    "snippet_forward",
                    "fallback",
                },
                ["<S-Tab>"] = { custom_insert_prev },
                ["<C-y>"] = { "accept", "fallback" },
                ["<C-n>"] = { "select_next", "fallback" },
                ["<C-p>"] = { "select_prev", "fallback" },
            },
            snippets = {
                preset = "luasnip",
            },
            sources = {
                default = { "lazydev", "lsp", "buffer", "snippets", "path" },
                providers = {
                    dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        -- make lazydev completions top priority (see `:h blink.cmp`)
                        score_offset = 100,
                    },
                    opencode_contexts = {
                        name = "OpencodeContexts",
                        module = "plugins.blink.opencode_contexts",
                    },
                },
                per_filetype = {
                    sql = { "snippets", "dadbod", "buffer" },
                    ["copilot-chat"] = { "snippets" },
                    DressingInput = { "opencode_contexts", "buffer", "path" },
                },
            },
            completion = {
                list = {
                    selection = {
                        preselect = vim.g.emacs_tab ~= true,
                    },
                    cycle = { from_top = false },
                },
                menu = {
                    auto_show = vim.g.emacs_tab ~= true,
                    max_height = 20,
                    draw = {
                        columns = columns,
                        components = {
                            source_name = {
                                text = function(ctx)
                                    return "[" .. ctx.source_name .. "]"
                                end,
                            },
                            label = {
                                text = function(ctx)
                                    return require("colorful-menu").blink_components_text(ctx)
                                end,
                                highlight = function(ctx)
                                    return require("colorful-menu").blink_components_highlight(ctx)
                                end,
                            },
                        },
                    },
                },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 250,
                    window = { border = "single" },
                },
            },
            cmdline = {
                completion = {
                    menu = {
                        auto_show = true,
                        draw = {
                            columns = {
                                { "label", "label_description" },
                            },
                        },
                    },
                },
            },
            fuzzy = { implementation = "prefer_rust_with_warning" },
        })

        require("colorful-menu").setup({})
    end,
}
