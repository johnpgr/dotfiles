-- DAP: nvim-dap + view + disasm + virtual-text + mason-dap

return {
	{
		"mfussenegger/nvim-dap",
		keys = {
			{ "<F1>", desc = "DAP Hover" },
			{ "<F5>", desc = "DAP continue" },
			{ "<F10>", desc = "DAP step over" },
			{ "<F11>", desc = "DAP step into" },
			{ "<F12>", desc = "DAP step out" },
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
			require("mason-nvim-dap").setup({})

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
	{ "jay-babu/mason-nvim-dap.nvim", lazy = true },
	{ "igorlfs/nvim-dap-view", lazy = true },
	{ "Jorenar/nvim-dap-disasm", lazy = true },
}
