-- Plugin specifications for lazy.nvim
-- All plugins load lazily by default

local term = os.getenv("TERM")
local is_kitty =  term == "xterm-kitty" or term == "xterm-ghostty" or term == "wezterm"
local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0

return {
    {
        "fenetikm/falcon",
        lazy = false,
    },
    {
        "https://github.com/sainnhe/everforest",
        config = function()
            vim.g.everforest_background = "soft"
            vim.g.everforest_better_performance = 1
            vim.g.everforest_disable_italic_comment = 1
            vim.g.everforest_disable_italic = 1
        end,
        lazy = false,
    },
    {
        "sainnhe/gruvbox-material",
        config = function()
            vim.g.gruvbox_material_background = "hard"
            vim.g.gruvbox_material_better_performance = 1
            vim.g.gruvbox_material_disable_italic_comment = 1
            vim.g.gruvbox_material_disable_italic = 1
            vim.g.gruvbox_material_foreground = "material"
        end,
        lazy = false,
    },
    {
        "travisvroman/adwaita.nvim",
        lazy = false,
        config = function()
            vim.g.adwaita_darker = true
        end,
    },
    {
        "2nthony/vitesse.nvim",
        lazy = false,
        dependencies = {
            "tjdevries/colorbuddy.nvim",
        },
        config = function()
            require("vitesse").setup({
                comment_italics = false,
                transparent_background = false,
                transparent_float_background = true, -- aka pum(popup menu) background
                reverse_visual = true,
                dim_nc = true,
                cmp_cmdline_disable_search_highlight_group = false, -- disable search highlight group for cmp item
                -- if `transparent_float_background` false, make telescope border color same as float background
                telescope_border_follow_float_background = false,
                -- similar to above, but for lspsaga
                lspsaga_border_follow_float_background = false,
                -- diagnostic virtual text background, like error lens
                diagnostic_virtual_text_background = false,

                -- override the `lua/vitesse/palette.lua`, go to file see fields
                colors = {},
                themes = {},
            })
        end,
    },
    { "Mofiqul/vscode.nvim",         lazy = false },
    { "sainnhe/sonokai",             lazy = false },
    { "Mofiqul/dracula.nvim",        lazy = false },

    -- Dependencies (loaded when required)
    { "nvim-lua/plenary.nvim",       lazy = true },
    { "nvim-tree/nvim-web-devicons", lazy = true },
    { "MunifTanjim/nui.nvim",        lazy = true },

    -- Undotree
    {
        "mbbill/undotree",
        cmd = "UndotreeToggle",
        keys = {
            { "<leader>tu", "<cmd>UndotreeToggle<cr>", desc = "Undotree" },
        },
    },

    -- Visual Multi
    {
        "mg979/vim-visual-multi",
        event = "VeryLazy",
        init = function()
            vim.cmd([[
                let g:VM_maps = {}
                let g:VM_maps["Goto Prev"] = "\[\["
                let g:VM_maps["Goto Next"] = "\]\]"
                nmap <C-M-n> <Plug>(VM-Select-All)
            ]])
        end,
    },

    -- Text Case
    {
        "johmsalas/text-case.nvim",
        event = "VeryLazy",
        config = function()
            require("textcase").setup({ prefix = "tc" })
        end,
    },

    -- Abolish
    { "tpope/vim-abolish",  event = "VeryLazy" },

    -- Dispatch
    { "tpope/vim-dispatch", cmd = { "Dispatch", "Make", "Focus", "Start" } },

    -- Mini Align
    {
        "nvim-mini/mini.align",
        keys = {
            { "ga", mode = { "n", "v" }, desc = "Align" },
            { "gA", mode = { "n", "v" }, desc = "Align with preview" },
        },
        config = function()
            require("mini.align").setup({
                mappings = {
                    start = "ga",
                    start_with_preview = "gA",
                },
            })
        end,
    },

    -- Blink.cmp (completion)
    {
        "saghen/blink.cmp",
        version = "v1.10.1",
        event = "InsertEnter",
        dependencies = {
            "L3MON4D3/LuaSnip",
            "rafamadriz/friendly-snippets",
            "xzbdmw/colorful-menu.nvim",
        },
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

            local function custom_insert_next(cmp)
                if not cmp.is_active() then
                    return cmp.show_and_insert()
                end
                vim.schedule(function()
                    require("blink.cmp.completion.list").select_next({ auto_insert = true })
                end)
                return true
            end

            local function custom_insert_prev(cmp)
                if not cmp.is_active() then
                    return cmp.show_and_insert()
                end
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
                        Text = "",
                        Method = "",
                        Function = "",
                        Constructor = "",
                        Field = "",
                        Variable = "",
                        Class = "",
                        Interface = "",
                        Module = "",
                        Property = "",
                        Unit = "",
                        Value = "",
                        Enum = "",
                        Keyword = "",
                        Snippet = "",
                        Color = "",
                        File = "",
                        Reference = "",
                        Folder = "",
                        EnumMember = "",
                        Constant = "",
                        Struct = "",
                        Event = "",
                        Operator = "",
                        TypeParameter = "",
                    },
                },
                keymap = {
                    preset = "none",
                    ["<C-space>"] = { toggle_menu },
                    ["<CR>"] = { "fallback" },
                    ["<Tab>"] = { tab_action, "snippet_forward", "fallback" },
                    ["<S-Tab>"] = { custom_insert_prev },
                    ["<C-y>"] = { "accept", "fallback" },
                    ["<C-n>"] = { "select_next", "fallback" },
                    ["<C-p>"] = { "select_prev", "fallback" },
                },
                snippets = { preset = "luasnip" },
                sources = {
                    default = { "lazydev", "lsp", "buffer", "snippets", "path" },
                    providers = {
                        dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
                        lazydev = {
                            name = "LazyDev",
                            module = "lazydev.integrations.blink",
                            score_offset = 100,
                        },
                    },
                    per_filetype = {
                        sql = { "snippets", "dadbod", "buffer" },
                        ["copilot-chat"] = { "snippets" },
                        DressingInput = { "buffer", "path" },
                    },
                },
                completion = {
                    list = {
                        selection = { preselect = vim.g.emacs_tab ~= true },
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
                cmdline = { enabled = false },
                fuzzy = { implementation = "prefer_rust_with_warning" },
            })

            require("colorful-menu").setup({})
        end,
    },

    -- LuaSnip
    {
        "L3MON4D3/LuaSnip",
        lazy = true,
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
            require("luasnip.loaders.from_vscode").lazy_load()
            require("luasnip").setup({})
        end,
    },

    -- Friendly Snippets
    { "rafamadriz/friendly-snippets", lazy = true },

    -- Colorful Menu
    { "xzbdmw/colorful-menu.nvim",    lazy = true },

    -- Compile Mode
    {
        "ej-shafran/compile-mode.nvim",
        version = "^5.0.0",
        dependencies = { "m00qek/baleia.nvim" },
        cmd = { "Compile", "Recompile" },
        config = function()
            local compile_mode = require("compile-mode")
            vim.g.compile_mode = {
                default_command = "",
                input_word_completion = true,
                baleia_setup = true,
                bang_expansion = true,
                error_regexp_table = {
                    nodejs = {
                        regex = "^\\s\\+at .\\+ (\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\))$",
                        filename = 1,
                        row = 2,
                        col = 3,
                        priority = 2,
                    },
                    typescript = {
                        regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
                        filename = 1,
                        row = 2,
                        col = 3,
                    },
                    typescript_new = {
                        regex = "^\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\) - error TS[1-9][0-9]*:",
                        filename = 1,
                        row = 2,
                        col = 3,
                    },
                    gradlew = {
                        regex = "^e:\\s\\+file://\\(.\\+\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
                        filename = 1,
                        row = 2,
                        col = 3,
                    },
                    ls_lint = {
                        regex = "\\v^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} (.+) failed for rules: .+$",
                        filename = 1,
                    },
                    sass = {
                        regex = "\\s\\+\\(.\\+\\) \\(\\d\\+\\):\\(\\d\\+\\)  .*$",
                        filename = 1,
                        row = 2,
                        col = 3,
                        type = compile_mode.level.WARNING,
                    },
                    kotlin = {
                        regex = "^\\%(e\\|w\\): file://\\(.*\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
                        filename = 1,
                        row = 2,
                        col = 3,
                    },
                    rust = {
                        regex = "^\\s*-->\\s\\+\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)$",
                        filename = 1,
                        row = 2,
                        col = 3,
                        priority = 2,
                    },
                    odin = {
                        regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)) Error:",
                        filename = 1,
                        row = 2,
                        col = 3,
                    },
                },
            }
        end,
    },

    -- Baleia (for compile-mode ANSI colors)
    { "m00qek/baleia.nvim",              version = "v1.3.0", lazy = true },

    -- Conform (formatting)
    {
        "stevearc/conform.nvim",
        event = "BufWritePre",
        cmd = "ConformInfo",
        keys = {
            {
                "<leader>lf",
                function()
                    require("conform").format({ async = true })
                end,
                desc = "Format buffer",
            },
        },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    lua = { "stylua", lsp_format = "fallback" },
                    python = { "isort", "black", lsp_format = "fallback" },
                    rust = { "rustfmt", lsp_format = "fallback" },
                    html = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                    css = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                    json = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                    javascript = { "oxfmt", lsp_format = "fallback" },
                    javascriptreact = { "oxfmt", lsp_format = "fallback" },
                    typescript = { "oxfmt", lsp_format = "fallback" },
                    typescriptreact = { "oxfmt", lsp_format = "fallback" },
                    astro = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
                    c = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
                    cpp = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
                    odin = { lsp_format = "fallback" },
                },
            })
        end,
    },

    -- Copilot
    {
        "zbirenbaum/copilot.lua",
        -- enabled = false,
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    hide_during_completion = true,
                    debounce = 75,
                    trigger_on_accept = true,
                    keymap = {
                        accept = "<M-l>",
                        accept_word = false,
                        accept_line = false,
                        next = "<M-]>",
                        prev = "<M-[>",
                        dismiss = "<C-]>",
                    },
                },
            })
        end,
    },

    -- Cord (Discord presence)
    {
        "vyfor/cord.nvim",
        event = "VeryLazy",
        config = function()
            require("cord").setup({})
        end,
    },

    -- DAP (Debug Adapter Protocol)
    {
        "mfussenegger/nvim-dap",
        keys = {
            { "<F1>",       desc = "DAP Hover" },
            { "<F5>",       desc = "DAP continue" },
            { "<F10>",      desc = "DAP step over" },
            { "<F11>",      desc = "DAP step into" },
            { "<F12>",      desc = "DAP step out" },
            { "<leader>dd", desc = "Toggle breakpoint" },
            { "<leader>dB", desc = "Conditional breakpoint" },
            { "<leader>dc", desc = "Continue" },
            { "<leader>dl", desc = "Run last" },
            { "<leader>do", desc = "Step over" },
            { "<leader>di", desc = "Step into" },
            { "<leader>dO", desc = "Step out" },
            { "<leader>dp", desc = "Pause" },
            { "<leader>ds", desc = "Stop" },
            { "<leader>du", desc = "Toggle debug UI" },
            { "<leader>dD", desc = "Toggle disassembly view" },
            { "<leader>dw", desc = "Add watch expression" },
        },
        dependencies = {
            "theHamsta/nvim-dap-virtual-text",
            "jay-babu/mason-nvim-dap.nvim",
            "igorlfs/nvim-dap-view",
            "Jorenar/nvim-dap-disasm",
        },
        config = function()
            local dap = require("dap")

            vim.fn.sign_define("DapBreakpoint", {
                text = "●",
                texthl = "DiagnosticError",
                linehl = "",
                numhl = "",
            })
            vim.fn.sign_define("DapStopped", {
                text = ">",
                texthl = "DiagnosticWarn",
                linehl = "",
                numhl = "",
            })
            vim.fn.sign_define("DapBreakpointRejected", {
                text = "R",
                texthl = "DiagnosticInfo",
                linehl = "",
                numhl = "",
            })

            require("nvim-dap-virtual-text").setup({ commented = true })
            require("mason-nvim-dap").setup({
                ensure_installed = { "kotlin" },
                automatic_installation = true,
            })

            require("dap-view").setup({
                winbar = {
                    controls = { enabled = false },
                    sections = { "scopes", "threads", "breakpoints", "watches", "disassembly", "repl" },
                    default_section = "scopes",
                    show_keymap_hints = false,
                    base_sections = {
                        scopes = { label = "[S]copes", keymap = "S" },
                        threads = { label = "[T]hreads", keymap = "T" },
                        breakpoints = { label = "[B]reakpoints", keymap = "B" },
                        watches = { label = "[W]atches", keymap = "W" },
                        repl = { label = "[R]EPL", keymap = "R" },
                    },
                },
                windows = {
                    size = 0.4,
                    position = "left",
                    terminal = { size = 0.3, position = "below", hide = {} },
                },
                auto_toggle = false,
                switchbuf = "usetab,uselast",
            })

            require("dap-disasm").setup({
                dapui_register = false,
                dapview_register = true,
                dapview = { keymap = "D", label = "[D]isassembly", short_label = "Disasm [D]" },
                sign = "DapStopped",
                ins_before_memref = 24,
                ins_after_memref = 24,
                columns = { "address", "instructionBytes", "instruction" },
            })

            -- Helper functions
            local function dap_view_is_open()
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.w[win].dapview_win then
                        return true
                    end
                end
                return false
            end

            local function dap_terminal_is_open()
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.w[win].dapview_win_term then
                        return true
                    end
                end
                return false
            end

            local function dap_ui_is_open()
                return dap_view_is_open() or dap_terminal_is_open()
            end

            local function clear_dap_virtual_text()
                local ok, virtual_text = pcall(require, "nvim-dap-virtual-text/virtual_text")
                if not ok then
                    return
                end
                virtual_text.clear_virtual_text()
                virtual_text.clear_last_frames()
            end

            local function open_dap_view_once()
                if dap_view_is_open() then
                    return
                end
                require("dap-view").open()
            end

            local function close_dap_view_if_idle()
                vim.defer_fn(function()
                    if next(dap.sessions()) ~= nil then
                        return
                    end
                    if not dap_ui_is_open() then
                        return
                    end
                    require("dap-view").close(true)
                end, 20)
            end

            local function clear_dap_state_if_idle()
                vim.defer_fn(function()
                    if next(dap.sessions()) ~= nil then
                        return
                    end
                    clear_dap_virtual_text()
                end, 20)
            end

            -- DAP listeners
            dap.listeners.after.event_initialized["dapview_auto_open"] = open_dap_view_once
            dap.listeners.after.event_terminated["dapview_auto_close"] = close_dap_view_if_idle
            dap.listeners.after.event_exited["dapview_auto_close"] = close_dap_view_if_idle
            dap.listeners.after.event_terminated["dap_virtual_text_cleanup"] = clear_dap_state_if_idle
            dap.listeners.after.event_exited["dap_virtual_text_cleanup"] = clear_dap_state_if_idle
            dap.listeners.after.disconnect["dap_virtual_text_cleanup"] = clear_dap_state_if_idle
            dap.listeners.after.event_stopped["dap_disasm_refresh"] = function()
                pcall(require("dap-disasm").refresh)
            end

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-float",
                callback = function(ev)
                    vim.keymap.set("n", "q", "<cmd>bdelete!<cr>", { buffer = ev.buf, silent = true })
                end,
            })

            -- Adapters
            local lldb_dap_path = vim.fn.exepath("lldb-dap")
            if lldb_dap_path == "" then
                lldb_dap_path = "lldb-dap"
            end

            dap.adapters.lldb = {
                type = "executable",
                command = lldb_dap_path,
                name = "lldb",
            }

            local kotlin_adapter_path = vim.fn.exepath("kotlin-debug-adapter")
            if kotlin_adapter_path == "" then
                kotlin_adapter_path = "kotlin-debug-adapter"
            end

            dap.adapters.kotlin = {
                type = "executable",
                command = kotlin_adapter_path,
                args = { "--interpreter=vscode" },
            }

            -- Configurations
            local lldb_launch = {
                name = "Launch (lldb-dap)",
                type = "lldb",
                request = "launch",
                console = "integratedTerminal",
                program = function()
                    local path = vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
                    if path == "" then
                        return dap.ABORT
                    end
                    return vim.fn.fnamemodify(path, ":p")
                end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
                args = {},
            }

            local lldb_attach = {
                name = "Attach (lldb-dap)",
                type = "lldb",
                request = "attach",
                pid = require("dap.utils").pick_process,
                cwd = "${workspaceFolder}",
            }

            local kotlin_launch = {
                name = "Launch Kotlin",
                type = "kotlin",
                request = "launch",
                projectRoot = "${workspaceFolder}",
                mainClass = function()
                    local main_class = vim.fn.input("Main class (e.g. com.example.MainKt): ")
                    if main_class == "" then
                        return dap.ABORT
                    end
                    return main_class
                end,
            }

            local kotlin_attach = {
                name = "Attach Kotlin (:5005)",
                type = "kotlin",
                request = "attach",
                projectRoot = "${workspaceFolder}",
                hostName = "localhost",
                port = 5005,
                timeout = 2000,
            }

            dap.configurations.c = { lldb_launch, lldb_attach }
            dap.configurations.cpp = { lldb_launch, lldb_attach }
            dap.configurations.rust = { lldb_launch, lldb_attach }
            dap.configurations.odin = { lldb_launch, lldb_attach }
            dap.configurations.kotlin = { kotlin_launch, kotlin_attach }

            -- Keymaps
            local function toggle_disassembly_view()
                local dapview = require("dap-view")
                if not dap_view_is_open() then
                    dapview.open()
                    dapview.show_view("disassembly")
                    return
                end
                if vim.bo.filetype == "dap-disassembly" then
                    dapview.show_view("scopes")
                    return
                end
                dapview.jump_to_view("disassembly")
            end

            vim.keymap.set("n", "<F1>", function()
                require("dap.ui.widgets").hover()
            end, { desc = "DAP Hover" })
            vim.keymap.set("n", "<F5>", function()
                require("dap").continue()
            end, { desc = "DAP continue" })
            vim.keymap.set("n", "<F10>", function()
                require("dap").step_over()
            end, { desc = "DAP step over" })
            vim.keymap.set("n", "<F11>", function()
                require("dap").step_into()
            end, { desc = "DAP step into" })
            vim.keymap.set("n", "<F12>", function()
                require("dap").step_out()
            end, { desc = "DAP step out" })
            vim.keymap.set("n", "<leader>dd", function()
                require("dap").toggle_breakpoint()
            end, { desc = "Toggle breakpoint" })
            vim.keymap.set("n", "<leader>dB", function()
                require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
            end, { desc = "Conditional breakpoint" })
            vim.keymap.set("n", "<leader>dc", function()
                require("dap").continue()
            end, { desc = "Continue" })
            vim.keymap.set("n", "<leader>dl", function()
                require("dap").run_last()
            end, { desc = "Run last" })
            vim.keymap.set("n", "<leader>do", function()
                require("dap").step_over()
            end, { desc = "Step over" })
            vim.keymap.set("n", "<leader>di", function()
                require("dap").step_into()
            end, { desc = "Step into" })
            vim.keymap.set("n", "<leader>dO", function()
                require("dap").step_out()
            end, { desc = "Step out" })
            vim.keymap.set("n", "<leader>dp", function()
                require("dap").pause()
            end, { desc = "Pause" })
            vim.keymap.set("n", "<leader>ds", function()
                clear_dap_virtual_text()
                require("dap").terminate()
                require("dap").disconnect()
                require("dap").close()
            end, { desc = "Stop" })
            vim.keymap.set("n", "<leader>du", function()
                local dapview = require("dap-view")
                if dap_ui_is_open() then
                    dapview.close(true)
                    return
                end
                dapview.open()
            end, { desc = "Toggle debug UI" })
            vim.keymap.set("n", "<leader>dD", toggle_disassembly_view, { desc = "Toggle disassembly view" })
            vim.keymap.set("n", "<leader>dw", function()
                require("dap-view").add_expr()
            end, { desc = "Add watch expression" })
        end,
    },

    { "theHamsta/nvim-dap-virtual-text", lazy = true },
    { "jay-babu/mason-nvim-dap.nvim",    lazy = true },
    { "igorlfs/nvim-dap-view",           lazy = true },
    { "Jorenar/nvim-dap-disasm",         lazy = true },

    -- Dadbod (Database)
    {
        "tpope/vim-dadbod",
        cmd = { "DB", "DBUI", "DBUIAddConnection" },
        dependencies = {
            "kristijanhusak/vim-dadbod-completion",
            "kristijanhusak/vim-dadbod-ui",
        },
    },
    { "kristijanhusak/vim-dadbod-completion", lazy = true },
    {
        "kristijanhusak/vim-dadbod-ui",
        cmd = { "DBUI", "DBUIAddConnection", "DBUIToggle" },
        keys = {
            { "<leader>ub", desc = "DBUI" },
            { "<leader>ua", "<cmd>DBUIAddConnection<cr>", desc = "Add new connection" },
        },
    },

    -- FFF (Fast File Finder)
    {
        "dmtrKovalenko/fff.nvim",
        event = "VeryLazy",
        build = function()
            pcall(function()
                require("fff.download").download_or_build_binary()
            end)
        end,
    },

    -- Git
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("gitsigns").setup({
                attach_to_untracked = true,
                preview_config = {
                    border = "single",
                    focusable = false,
                },
            })
        end,
    },

    {
        "NeogitOrg/neogit",
        dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
        cmd = { "Neogit", "NeogitLogCurrent" },
        keys = {
            {
                "<M-g>",
                function()
                    require("neogit").open({ kind = "replace" })
                end,
                desc = "Git status",
            },
            {
                "<leader>gg",
                function()
                    require("neogit").open({ kind = "replace" })
                end,
                desc = "Git status",
            },
            {
                "<leader>gc",
                function()
                    require("neogit.buffers.commit_view").new("HEAD"):open("replace")
                end,
                desc = "Git commit",
            },
            { "<leader>gb", "<cmd>Neogit branch<cr>",    desc = "Git branch" },
            { "<leader>gL", "<cmd>NeogitLogCurrent<cr>", desc = "Git log" },
        },
        config = function()
            require("neogit").setup({
                graph_style = is_kitty and "kitty" or "ascii",
                commit_editor = {
                    kind = "vsplit",
                    show_staged_diff = false,
                },
                console_timeout = 5000,
                auto_show_console = false,
            })
        end,
    },

    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewFileHistory" },
        keys = {
            { "<leader>gD", ":DiffviewOpen ",               desc = "Git DiffView" },
            {
                "<leader>gh",
                function()
                    vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
                end,
                desc = "Git file history (Current)",
            },
            { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git file history (All)" },
        },
        config = function()
            require("diffview").setup({
                view = {
                    merge_tool = {
                        layout = "diff3_mixed",
                        disable_diagnostics = true,
                        winbar_info = true,
                    },
                },
            })
        end,
    },

    -- Image support (kitty only)
    {
        "3rd/image.nvim",
        enabled = image_enabled,
        ft = { "markdown", "image" },
        config = function()
            require("image").setup({
                backend = "kitty",
                processor = "magick_cli",
                integrations = {
                    markdown = { only_render_image_at_cursor = true },
                },
                hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
            })
        end,
    },

    -- LSP
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "mason-org/mason.nvim",
            "folke/lazydev.nvim",
            "yioneko/nvim-vtsls",
        },
        config = function()
            local kotlin_root_markers = {
                "settings.gradle.kts",
                "settings.gradle",
                "build.gradle.kts",
                "build.gradle",
                "pom.xml",
                "workspace.json",
                ".git",
            }

            vim.lsp.config("kotlin_lsp", {
                root_dir = function(bufnr, on_dir)
                    local fname = vim.api.nvim_buf_get_name(bufnr)
                    if fname == "" then
                        on_dir(vim.uv.cwd())
                        return
                    end
                    local real_fname = vim.uv.fs_realpath(fname)
                    local root = vim.fs.root(real_fname or fname, kotlin_root_markers)
                    if not root and real_fname then
                        root = vim.fs.root(fname, kotlin_root_markers)
                    end
                    on_dir(root or vim.fs.dirname(real_fname or fname) or vim.uv.cwd())
                end,
            })

            vim.lsp.config("asm_lsp", {
                filetypes = { "asm", "vmasm" },
                root_dir = function(bufnr, on_dir)
                    local fname = vim.api.nvim_buf_get_name(bufnr)
                    if fname == "" then
                        on_dir(vim.uv.cwd())
                        return
                    end
                    local root = vim.fs.root(fname, { ".asm-lsp.toml", ".git" })
                    on_dir(root or vim.fs.dirname(fname) or vim.uv.cwd())
                end,
                get_language_id = function(_, filetype)
                    if filetype == "dap-disassembly" then
                        return "asm"
                    end
                    return filetype
                end,
                single_file_support = true,
            })

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-disassembly",
                callback = function(args)
                    if vim.fn.executable("asm-lsp") ~= 1 then
                        return
                    end
                    vim.lsp.start({
                        name = "asm_lsp",
                        cmd = { "asm-lsp" },
                        root_dir = vim.uv.cwd(),
                        single_file_support = true,
                        workspace_required = false,
                        get_language_id = function()
                            return "asm"
                        end,
                    }, {
                        bufnr = args.buf,
                        silent = true,
                        reuse_client = function(client, config)
                            return client.name == config.name and client.config.root_dir == config.root_dir
                        end,
                    })
                end,
            })

            vim.lsp.enable({
                "lua_ls",
                "vtsls",
                "clangd",
                "html",
                "cssls",
                "jsonls",
                "basedpyright",
                "zls",
                "dartls",
                "glsl_analyzer",
                "kotlin_lsp",
                "astro",
                "rust_analyzer",
                "sqlls",
                "oxlint",
                "ols",
                "asm_lsp",
            })

            require("lspconfig.configs").vtsls = require("vtsls").lspconfig

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if not client or client.name ~= "vtsls" then
                        return
                    end

                    local items = {
                        {
                            name = "restart_tsserver",
                            desc = "Does not restart vtsls itself, but restarts the underlying tsserver.",
                        },
                        {
                            name = "open_tsserver_log",
                            desc = "It will open prompt if logging has not been enabled.",
                        },
                        { name = "reload_projects",        desc = "Reload tsserver projects for the workspace." },
                        {
                            name = "select_ts_version",
                            desc = "Select version of ts either from workspace or global.",
                        },
                        { name = "goto_project_config",    desc = "Open tsconfig.json." },
                        { name = "goto_source_definition", desc = "Go to the source definition instead of typings." },
                        { name = "file_references",        desc = "Show references of the current file." },
                        {
                            name = "rename_file",
                            desc = "Rename the current file and update all the related paths in the project.",
                        },
                        { name = "organize_imports",      desc = "Organize imports in the current file." },
                        { name = "sort_imports",          desc = "Sort imports in the current file." },
                        { name = "remove_unused_imports", desc = "Remove unused imports from the current file." },
                        { name = "fix_all",               desc = "Apply all available code fixes." },
                        { name = "remove_unused",         desc = "Remove unused variables and symbols." },
                        { name = "add_missing_imports",   desc = "Add missing imports for unresolved symbols." },
                        { name = "source_actions",        desc = "Pick applicable source actions (same as above)" },
                    }

                    vim.keymap.set("n", "<leader>lt", function()
                        vim.ui.select(items, {
                            prompt = "TypeScript LSP actions",
                            format_item = function(entry)
                                return string.format("%-24s %s", entry.name, entry.desc or "")
                            end,
                        }, function(selection)
                            if not selection or not selection.name then
                                return
                            end
                            vim.cmd("VtsExec " .. selection.name)
                        end)
                    end, { desc = "Typescript LSP actions (vtsls)", buffer = args.buf })
                end,
            })
        end,
    },

    {
        "mason-org/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        build = ":MasonUpdate",
        config = function()
            require("mason").setup({})
        end,
    },

    {
        "folke/lazydev.nvim",
        ft = "lua",
        config = function()
            require("lazydev").setup({
                library = {
                    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                },
            })
        end,
    },

    { "mfussenegger/nvim-jdtls",              ft = "java" },
    { "yioneko/nvim-vtsls",                   lazy = true },

    -- Neo-tree
    {
        "nvim-neo-tree/neo-tree.nvim",
        version = "v3.x",
        dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
        cmd = "Neotree",
        keys = {
            {
                "<leader>b",
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
            ---@type neotree.Config?
            local opts = {
                enable_git_status = false,
                enable_diagnostics = false,
                filesystem = {
                    follow_current_file = { enabled = true, leave_dirs_open = false },
                },
                window = { width = 30 },
            }

            if not vim.g.icons_enabled then
                opts.default_component_configs = {
                    indent = {
                        with_expanders = true,
                        expander_collapsed = ">",
                        expander_expanded = "v",
                    },
                }
                opts.renderers = {
                    directory = { { "indent" }, { "name" } },
                    file = { { "indent" }, { "name" } },
                }
            end

            require("neo-tree").setup(opts)
        end,
    },

    -- Smart Splits (seamless navigation/resize across nvim + wezterm/kitty/tmux)
    {
        "johnpgr/smart-splits.nvim",
        branch = "perf/async-wezterm-cli",
        lazy = false,
        build = vim.fn.has("win32") == 0 and "./kitty/install-kittens.bash" or nil,
        keys = {
            {
                "<C-h>",
                function()
                    require("smart-splits").move_cursor_left()
                end,
                desc = "Focus split left",
            },
            {
                "<C-j>",
                function()
                    require("smart-splits").move_cursor_down()
                end,
                desc = "Focus split down",
            },
            {
                "<C-k>",
                function()
                    require("smart-splits").move_cursor_up()
                end,
                desc = "Focus split up",
            },
            {
                "<C-l>",
                function()
                    require("smart-splits").move_cursor_right()
                end,
                desc = "Focus split right",
            },
            {
                "<M-h>",
                function()
                    require("smart-splits").resize_left()
                end,
                desc = "Resize split left",
            },
            {
                "<M-j>",
                function()
                    require("smart-splits").resize_down()
                end,
                desc = "Resize split down",
            },
            {
                "<M-k>",
                function()
                    require("smart-splits").resize_up()
                end,
                desc = "Resize split up",
            },
            {
                "<M-l>",
                function()
                    require("smart-splits").resize_right()
                end,
                desc = "Resize split right",
            },
        },
        config = function()
            require("smart-splits").setup({
                at_edge = "stop",
            })
        end,
    },

    -- Oil
    {
        "stevearc/oil.nvim",
        cmd = "Oil",
        keys = {
            { "<leader>e", "<cmd>Oil<cr>", desc = "Explore" },
        },
        config = function()
            local permission_hlgroups = {
                ["-"] = "NonText",
                ["r"] = "DiagnosticSignWarn",
                ["w"] = "DiagnosticSignError",
                ["x"] = "DiagnosticSignOk",
            }
            local columns = {
                {
                    "permissions",
                    highlight = function(permission_str)
                        local hls = {}
                        for i = 1, #permission_str do
                            local char = permission_str:sub(i, i)
                            table.insert(hls, { permission_hlgroups[char], i - 1, i })
                        end
                        return hls
                    end,
                },
                { "size",  highlight = "Special" },
                { "mtime", highlight = "Number" },
            }

            if vim.g.icons_enabled then
                table.insert(columns, { "icon", add_padding = false })
            end

            local function oil_action_run_cmd_on_file()
                local oil = require("oil")
                local entry = oil.get_cursor_entry()
                local cwd = oil.get_current_dir()

                if not entry then
                    return
                end

                vim.ui.input({ prompt = "Enter command: " }, function(cmd)
                    if not cmd then
                        return
                    end

                    local full_path = cwd .. entry.name

                    local function show_terminal(cmd_array)
                        vim.cmd("botright new")
                        vim.fn.jobstart(cmd_array, {
                            on_exit = function(_, code)
                                if code ~= 0 then
                                    vim.notify("Command exited with code: " .. code, vim.log.levels.WARN)
                                end
                            end,
                            term = true,
                        })
                        vim.cmd("startinsert")
                    end

                    if cmd and cmd ~= "" then
                        local command_string = cmd .. " " .. vim.fn.shellescape(full_path)
                        show_terminal({ "sh", "-c", command_string })
                    else
                        local stat = vim.uv.fs_stat(full_path)
                        if stat and stat.type == "file" then
                            if bit.band(stat.mode, tonumber("100", 8)) > 0 then
                                show_terminal({ full_path })
                            else
                                vim.ui.select({ "Yes", "No" }, {
                                    prompt = "File is not executable. Make it executable and run?",
                                }, function(choice)
                                    if choice == "Yes" then
                                        local chmod_res = vim.system({ "chmod", "+x", full_path }):wait()
                                        if chmod_res.code == 0 then
                                            vim.notify("Made file executable: " .. entry.name)
                                            show_terminal({ full_path })
                                        else
                                            vim.notify(
                                                "Failed to make file executable: " .. entry.name,
                                                vim.log.levels.ERROR
                                            )
                                        end
                                    else
                                        vim.notify("Aborted execution of: " .. entry.name)
                                    end
                                end)
                            end
                        else
                            vim.notify("Not a valid file: " .. entry.name, vim.log.levels.WARN)
                        end
                    end
                end)
            end

            require("oil").setup({
                lsp_file_methods = { enabled = vim.version().minor ~= 12 },
                columns = columns,
                skip_confirm_for_simple_edits = true,
                view_options = {
                    show_hidden = false,
                    is_always_hidden = function(name, _)
                        return name == ".." or name == "../"
                    end,
                },
                keymaps = {
                    ["q"] = "actions.close",
                    ["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
                    ["?"] = "actions.show_help",
                    ["<CR>"] = "actions.select",
                    ["<F1>"] = oil_action_run_cmd_on_file,
                    ["<F5>"] = "actions.refresh",
                    ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
                    ["-"] = { "actions.parent", mode = "n" },
                    ["<Left>"] = { "actions.parent", mode = "n" },
                    ["<Right>"] = { "actions.select", mode = "n" },
                    ["H"] = "actions.toggle_hidden",
                },
                confirmation = { border = "single" },
                win_options = {
                    winbar = "%!v:lua.get_oil_winbar()",
                    signcolumn = "no",
                    foldcolumn = "1",
                },
                use_default_keymaps = false,
                watch_for_changes = true,
                constrain_cursor = "name",
            })
        end,
    },

    -- Quicker (quickfix improvements)
    {
        "stevearc/quicker.nvim",
        ft = "qf",
        keys = {
            {
                "<leader>q",
                function()
                    require("quicker").toggle()
                end,
                desc = "Quickfix list",
            },
        },
        config = function()
            require("quicker").setup({
                keys = {
                    {
                        ">",
                        function()
                            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
                        end,
                        desc = "Expand quickfix context",
                    },
                    {
                        "<",
                        function()
                            require("quicker").collapse()
                        end,
                        desc = "Collapse quickfix context",
                    },
                },
            })
        end,
    },

    -- Refer (fuzzy finder)
    {
        "juniorsundar/refer.nvim",
        event = "VeryLazy",
        config = function()
            local function set_search_highlight(query)
                if not query or query == "" then
                    return
                end
                vim.opt.hlsearch = true
                vim.fn.setreg("/", "\\V" .. vim.fn.escape(query, "\\"))
            end

            local function default_live_grep_command(query)
                set_search_highlight(query)
                return { "rg", "--vimgrep", "--smart-case", "--", query }
            end

            local function refer_entry_to_qf_item(candidate, parser)
                local text
                local parsed

                if type(candidate) == "table" then
                    text = type(candidate.text) == "string" and candidate.text or ""
                    if type(candidate.data) == "table" then
                        parsed = candidate.data
                    end
                else
                    text = type(candidate) == "string" and candidate or ""
                end

                local item = { text = text }
                if parsed == nil and type(parser) ~= "function" then
                    return item
                end

                if parsed == nil then
                    parsed = parser(text)
                end

                if not parsed then
                    return item
                end

                if parsed.filename then
                    item.filename = parsed.filename
                end
                if parsed.lnum then
                    item.lnum = parsed.lnum
                end
                if parsed.col then
                    item.col = parsed.col
                end

                if parsed.content then
                    item.text = parsed.content
                elseif parsed.filename and parsed.lnum then
                    local parsed_lnum = tonumber(parsed.lnum)
                    local parsed_col = tonumber(parsed.col)
                    local _, _, text_lnum, text_col, content = text:find("^.*:(%d+):(%d+):(.*)$")

                    if
                        content
                        and tonumber(text_lnum) == parsed_lnum
                        and (not parsed_col or tonumber(text_col) == parsed_col)
                    then
                        item.text = content
                        return item
                    end

                    local _, _, text_lnum_no_col, content_no_col = text:find("^.*:(%d+):(.*)$")
                    if content_no_col and tonumber(text_lnum_no_col) == parsed_lnum then
                        item.text = content_no_col
                        return item
                    end

                    local prefix_col = string.format("%s:%d:%d:", parsed.filename, parsed.lnum, parsed.col or 0)
                    local prefix_no_col = string.format("%s:%d:", parsed.filename, parsed.lnum)

                    if vim.startswith(text, prefix_col) then
                        item.text = text:sub(#prefix_col + 1)
                    elseif vim.startswith(text, prefix_no_col) then
                        item.text = text:sub(#prefix_no_col + 1)
                    end
                end

                return item
            end

            local function send_all_refer_matches_to_qf(_, builtin)
                local picker = builtin and builtin.picker or nil
                local matches = picker and picker.current_matches or {}
                if #matches == 0 then
                    return
                end

                local items = {}
                for _, candidate in ipairs(matches) do
                    table.insert(items, refer_entry_to_qf_item(candidate, picker.parser))
                end

                local title = picker.opts.prompt or "Refer Selection"
                picker:close()

                pcall(require, "quicker")

                vim.schedule(function()
                    vim.fn.setqflist({}, " ", {
                        title = title,
                        items = items,
                    })
                    vim.cmd("copen")
                end)
            end

            require("refer").setup({
                on_close = function()
                    vim.cmd("nohlsearch")
                end,
                providers = {
                    grep = { grep_command = default_live_grep_command },
                },
                keymaps = {
                    ["<C-q>"] = send_all_refer_matches_to_qf,
                },
            })
            require("refer").setup_ui_select()
        end,
    },

    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local nvim_treesitter = require("nvim-treesitter")
            local treesitter_dir = vim.fs.normalize(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter")

            if vim.fn.isdirectory(treesitter_dir) == 1 then
                vim.opt.rtp:remove(treesitter_dir)
                vim.opt.rtp:append(treesitter_dir)
            end

            -- Use pre-compiled binaries instead of building from source
            require("nvim-treesitter.install").prefer_git = false
            nvim_treesitter.setup({})

            local function is_large_buffer(bufnr)
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if bufname == "" then
                    return false
                end

                local max_filesize = 1024 * 1024
                local ok, stats = pcall(vim.uv.fs_stat, bufname)
                return ok and stats and stats.size > max_filesize
            end

            local function resolve_lang(bufnr, lang)
                if lang and lang ~= "" then
                    return lang
                end

                local filetype = vim.bo[bufnr].filetype
                local ok, resolved = pcall(vim.treesitter.language.get_lang, filetype)
                if ok and resolved then
                    return resolved
                end

                local filetype_to_lang = {
                    javascriptreact = "tsx",
                    typescriptreact = "tsx",
                }

                return filetype_to_lang[filetype]
            end

            local ts_start = vim.treesitter.start

            local function start_treesitter(bufnr, lang)
                bufnr = bufnr or vim.api.nvim_get_current_buf()
                if vim.bo[bufnr].buftype ~= "" or is_large_buffer(bufnr) then
                    return
                end

                local resolved_lang = resolve_lang(bufnr, lang)
                if resolved_lang then
                    pcall(ts_start, bufnr, lang or resolved_lang)
                end
            end

            if vim.g.treesitter_enabled then
                local group = vim.api.nvim_create_augroup("TreesitterAutoStart", { clear = true })

                vim.api.nvim_create_autocmd("FileType", {
                    group = group,
                    callback = function(args)
                        start_treesitter(args.buf)
                    end,
                })

                vim.schedule(function()
                    start_treesitter(vim.api.nvim_get_current_buf())
                end)
            else
                local allowed_langs = {
                    markdown = true,
                    javascript = true,
                    typescript = true,
                    tsx = true,
                }

                ---@diagnostic disable-next-line: duplicate-set-field
                vim.treesitter.start = function(bufnr, lang)
                    bufnr = bufnr or vim.api.nvim_get_current_buf()
                    local bufname = vim.api.nvim_buf_get_name(bufnr)
                    if bufname == "" then
                        return ts_start(bufnr, lang)
                    end
                    local resolved_lang = resolve_lang(bufnr, lang)
                    if resolved_lang and allowed_langs[resolved_lang] then
                        return ts_start(bufnr, lang or resolved_lang)
                    end
                end
            end
        end,
    },

    -- Which Key
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")
            wk.setup({
                preset = "helix",
                icons = { mappings = false },
                win = {
                    border = "single",
                    height = { min = 4, max = 10 },
                },
            })
            wk.add({
                { "<leader>f",  group = "file" },
                { "<leader>s",  group = "search" },
                { "<leader>g",  group = "git" },
                { "<leader>gl", group = "list" },
                { "<leader>h",  group = "hunk" },
                { "<leader>l",  group = "lsp" },
                { "<leader>t",  group = "toggle" },
                { "<leader>i",  group = "insert" },
                { "<leader>d",  group = "debug" },
                { "<leader>c",  group = "opencode" },
            })
        end,
    },

    -- Transparent
    {
        "xiyaowong/transparent.nvim",
        lazy = false,
        config = function()
            require("transparent").setup({
                extra_groups = {
                    "VertSplit",
                    "NormalFloat",
                    "SignColumn",
                    "FoldColumn",
                    "WinBar",
                    "WinBarNC",
                    "TabLine",
                    "TabLineFill",
                    "TabLineSel",
                    "Directory",
                    "NeoTreeNormal",
                    "NeoTreeNormalNC",
                    "NeoTreeEndOfBuffer",
                    "WhichKeyTitle",
                    "FloatBorder",
                    "SpecialKey",
                },
            })
        end,
    },
    { "dgagn/diagflow.nvim",      opts = {},   event = "BufRead" },
}
