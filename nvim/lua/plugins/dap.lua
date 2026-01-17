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
                desc = "Breakpoint",
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
            {
                "<leader>dr",
                function()
                    require("dap").repl.open()
                end,
                desc = "REPL",
            },
            {
                "<leader>dt",
                function()
                    require("dap").terminate()
                end,
                desc = "Terminate",
            },
            {
                "<leader>du",
                function()
                    require("dapui").toggle()
                end,
                desc = "DAP UI",
            },
            {
                "<leader>de",
                function()
                    require("dapui").eval(nil, { enter = true })
                end,
                desc = "Eval",
            },
        },
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "theHamsta/nvim-dap-virtual-text",
            "nvim-neotest/nvim-nio",
            "jay-babu/mason-nvim-dap.nvim",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            vim.fn.sign_define("DapBreakpoint", {
                text = "B",
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

            dapui.setup({
                expand_lines = true,
                controls = { enabled = false },
                floating = { border = "single" },
                render = {
                    max_type_length = 60,
                    max_value_lines = 200,
                },
                layouts = {
                    {
                        elements = {
                            { id = "scopes", size = 0.5 },
                            { id = "watches", size = 0.25 },
                            { id = "breakpoints", size = 0.25 },
                        },
                        size = 40,
                        position = "left",
                    },
                    {
                        elements = {
                            { id = "stacks", size = 0.5 },
                            { id = "repl", size = 0.5 },
                        },
                        size = 12,
                        position = "bottom",
                    },
                },
            })

            require("nvim-dap-virtual-text").setup({
                commented = true,
            })

            require("mason-nvim-dap").setup({
                ensure_installed = { "codelldb" },
                automatic_installation = true,
            })

            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close()
            end

            local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = codelldb_path,
                    args = { "--port", "${port}" },
                },
            }

            local codelldb_config = {
                name = "Launch",
                type = "codelldb",
                request = "launch",
                program = function()
                    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
                end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
                args = {},
            }

            local codelldb_attach = {
                name = "Attach",
                type = "codelldb",
                request = "attach",
                pid = require("dap.utils").pick_process,
                cwd = "${workspaceFolder}",
            }

            dap.configurations.c = { codelldb_config, codelldb_attach }
            dap.configurations.cpp = dap.configurations.c
        end,
    },
}
