local function dap_view_is_open()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.w[win].dapview_win then
            return true
        end
    end
    return false
end

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

return {
    {
        "mfussenegger/nvim-dap",
        cmd = {
            "DapContinue",
            "DapToggleBreakpoint",
            "DapTerminate",
            "DapStepInto",
            "DapStepOver",
            "DapStepOut",
            "DapPause",
            "DapRestart",
            "DapRunLast",
            "DapViewOpen",
            "DapViewClose",
            "DapViewToggle",
            "DapViewJump",
            "DapViewShow",
            "DapDisasm",
            "DapDisasmSetMemref",
        },
        keys = {
            {
                "<F5>",
                function()
                    require("dap").continue()
                end,
                desc = "DAP continue",
            },
            {
                "<F10>",
                function()
                    require("dap").step_over()
                end,
                desc = "DAP step over",
            },
            {
                "<F11>",
                function()
                    require("dap").step_into()
                end,
                desc = "DAP step into",
            },
            {
                "<F12>",
                function()
                    require("dap").step_out()
                end,
                desc = "DAP step out",
            },
            {
                "<leader>dd",
                function()
                    require("dap").toggle_breakpoint()
                end,
                desc = "Toggle breakpoint",
            },
            {
                "<leader>dB",
                function()
                    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
                end,
                desc = "Conditional breakpoint",
            },
            {
                "<leader>dc",
                function()
                    require("dap").continue()
                end,
                desc = "Continue",
            },
            {
                "<leader>dl",
                function()
                    require("dap").run_last()
                end,
                desc = "Run last",
            },
            {
                "<leader>do",
                function()
                    require("dap").step_over()
                end,
                desc = "Step over",
            },
            {
                "<leader>di",
                function()
                    require("dap").step_into()
                end,
                desc = "Step into",
            },
            {
                "<leader>dO",
                function()
                    require("dap").step_out()
                end,
                desc = "Step out",
            },
            {
                "<leader>dp",
                function()
                    require("dap").pause()
                end,
                desc = "Pause",
            },
            -- {
            --     "<leader>dr",
            --     function()
            --         require("dap").repl.open()
            --     end,
            --     desc = "Open REPL",
            -- },
            {
                "<leader>ds",
                function()
                    require("dap").terminate()
                    require("dap").disconnect()
                    require("dap").close()
                end,
                desc = "Stop",
            },
            {
                "<leader>du",
                function()
                    require("dap-view").toggle()
                end,
                desc = "Toggle debug UI",
            },
            {
                "<leader>dD",
                toggle_disassembly_view,
                desc = "Toggle disassembly view",
            },
            {
                "<leader>de",
                function()
                    require("dap-view").add_expr()
                end,
                desc = "Add watch expression",
            },
        },
        dependencies = {
            "theHamsta/nvim-dap-virtual-text",
            "jay-babu/mason-nvim-dap.nvim",
            {
                "igorlfs/nvim-dap-view",
                config = function()
                    require("dap-view").setup({
                        winbar = {
                            sections = {
                                "scopes",
                                "threads",
                                "breakpoints",
                                "watches",
                                "disassembly",
                                "console",
                                "repl",
                            },
                            default_section = "scopes",
                            show_keymap_hints = true,
                        },
                        windows = {
                            size = 0.3,
                            position = "below",
                            terminal = {
                                size = 0.35,
                                position = "right",
                                hide = {},
                            },
                        },
                        -- We manage open/close via nvim-dap listeners below.
                        auto_toggle = false,
                        switchbuf = "usetab,uselast",
                    })
                end,
            },
            {
                "Jorenar/nvim-dap-disasm",
                dependencies = { "igorlfs/nvim-dap-view" },
                config = function()
                    require("dap-disasm").setup({
                        dapui_register = false,
                        dapview_register = true,
                        dapview = {
                            keymap = "D",
                            label = "Disassembly [D]",
                            short_label = "Disasm [D]",
                        },
                        sign = "DapStopped",
                        ins_before_memref = 24,
                        ins_after_memref = 24,
                        columns = {
                            "address",
                            "instructionBytes",
                            "instruction",
                        },
                    })
                end,
            },
        },
        config = function()
            local dap = require("dap")

            -- Migration note:
            -- nvim-dap-ui was intentionally replaced by nvim-dap-view because
            -- dap-ui has no native disassembly section and does not support
            -- registering arbitrary custom panes. Disassembly in DAP uses the
            -- `disassemble` request, so we wire nvim-dap-disasm into nvim-dap-view.
            --
            -- lldb-dap supports disassembly and instruction-level features, so
            -- this setup gives an IDE-like source + assembly workflow.
            --
            -- How to use:
            -- - <leader>du toggles the debug UI
            -- - <leader>dD toggles the disassembly section
            -- - <leader>dr opens REPL
            -- - Console/program output goes to nvim-dap terminal and REPL

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

            require("nvim-dap-virtual-text").setup({
                commented = true,
            })

            require("mason-nvim-dap").setup({
                ensure_installed = { "kotlin" },
                automatic_installation = true,
            })

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
                    if not dap_view_is_open() then
                        return
                    end
                    require("dap-view").close(true)
                end, 20)
            end

            dap.listeners.after.event_initialized["dapview_auto_open"] = open_dap_view_once
            dap.listeners.after.event_terminated["dapview_auto_close"] = close_dap_view_if_idle
            dap.listeners.after.event_exited["dapview_auto_close"] = close_dap_view_if_idle

            -- Force disassembly refresh whenever execution stops, so the view
            -- follows the current instruction pointer after each step/continue.
            dap.listeners.after.event_stopped["dap_disasm_refresh"] = function()
                pcall(require("dap-disasm").refresh)
            end

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
        end,
    },
}
