-- GitHub Copilot: official copilot-language-server driving Neovim's native
-- inline completion, plus sidekick.nvim for Next Edit Suggestions (NES).
--
-- NES is deliberately conservative: it only fires when leaving Insert mode,
-- so it never competes with ghost text while typing.
--
-- Requires: npm install --global @github/copilot-language-server (Node >= 20.8)
-- Sign in with :LspCopilotSignIn

vim.pack.add({
	"https://github.com/folke/sidekick.nvim",
})

-- --------------------------------------------------------------------------
-- Copilot language server
-- --------------------------------------------------------------------------
-- Defined inline rather than relying on nvim-lspconfig's `lsp/copilot.lua`,
-- which the pinned revision predates.

local copilot_cmd = "copilot-language-server"
if vim.fn.executable(copilot_cmd) ~= 1 then
	local mason_cmd = vim.fn.stdpath("data") .. "/mason/bin/copilot-language-server"
	if vim.fn.executable(mason_cmd) == 1 then
		copilot_cmd = mason_cmd
	end
end

---@param bufnr integer
---@param client vim.lsp.Client
local function sign_in(bufnr, client)
	client:request("signIn", vim.empty_dict(), function(err, result)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end

		if result.command then
			vim.fn.setreg("+", result.userCode)
			vim.fn.setreg("*", result.userCode)
			local continue = vim.fn.confirm(
				"Copied your one-time code to clipboard.\nOpen the browser to complete the sign-in process?",
				"&Yes\n&No"
			)
			-- handle the case where the user chooses to open the browser and complete the sign-in
			if continue == 1 then
				client:exec_cmd(result.command, { bufnr = bufnr }, function(cmd_err, cmd_result)
					if cmd_err then
						vim.notify(cmd_err.message, vim.log.levels.ERROR)
						return
					end
					if cmd_result.status == "OK" then
						vim.notify("Signed in as " .. cmd_result.user .. ".")
					end
				end)
			end
		end

		-- handle the case where the user needs to enter the code manually
		if result.status == "PromptUserDeviceFlow" then
			vim.notify("Enter your one-time code " .. result.userCode .. " in " .. result.verificationUri)
		-- handle the case where the user is already signed in
		elseif result.status == "AlreadySignedIn" then
			vim.notify("Already signed in as " .. result.user .. ".")
		end
	end)
end

---@param client vim.lsp.Client
local function sign_out(_, client)
	client:request("signOut", vim.empty_dict(), function(err, result)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end
		if result.status == "NotSignedIn" then
			vim.notify("Not signed in.")
		end
	end)
end

vim.lsp.config("copilot", {
	cmd = { copilot_cmd, "--stdio" },
	root_markers = { ".git" },
	init_options = {
		editorInfo = { name = "Neovim", version = tostring(vim.version()) },
		editorPluginInfo = { name = "Neovim", version = tostring(vim.version()) },
	},
	settings = {
		telemetry = { telemetryLevel = "all" },
	},
	on_attach = function(client, bufnr)
		vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignIn", function()
			sign_in(bufnr, client)
		end, { desc = "Sign in Copilot with GitHub" })

		vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignOut", function()
			sign_out(bufnr, client)
		end, { desc = "Sign out Copilot with GitHub" })
	end,
})

-- --------------------------------------------------------------------------
-- Next Edit Suggestions
-- --------------------------------------------------------------------------

require("sidekick").setup({
	nes = {
		-- Only request after finishing an insertion, not while typing.
		-- (Default also includes "TextChanged", which is noisy.)
		trigger = {
			events = { "ModeChanged i:n" },
		},
		debounce = 250,
		diff = {
			inline = "words",
			-- Only render the diff once the cursor reaches the edit.
			show = "always",
		},
		signs = true,
		jumplist = true,
	},
	cli = {
		-- Persist Pi (and other CLIs) in tmux so send/submit use real Enter
		-- keys instead of pasting into a Neovim :term (which fails for Pi).
		mux = {
			backend = "tmux",
			enabled = true,
			create = "split",
		},
	},
})

-- --------------------------------------------------------------------------
-- Native inline completion
-- --------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("copilot_inline_completion", { clear = true }),
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if not client or client.name ~= "copilot" then
			return
		end

		if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, event.buf) then
			vim.lsp.inline_completion.enable(true, { bufnr = event.buf })
		end
	end,
})

-- --------------------------------------------------------------------------
-- Keymaps
-- --------------------------------------------------------------------------
-- Inline completion stays on insert-mode keys. NES uses normal-mode <Tab>:
-- jump to the edit, then accept/dismiss via selabel.
-- <C-l> is normal-mode tmux navigation, so Copilot only claims it in insert.

vim.keymap.set("i", "<C-l>", function()
	if vim.lsp.inline_completion.get() then
		return ""
	end
	return "<C-l>"
end, { expr = true, silent = true, desc = "Accept Copilot completion" })

vim.keymap.set({ "i", "n" }, "<M-]>", function()
	vim.lsp.inline_completion.select({ count = 1 })
end, { desc = "Next Copilot completion" })

vim.keymap.set({ "i", "n" }, "<M-[>", function()
	vim.lsp.inline_completion.select({ count = -1 })
end, { desc = "Previous Copilot completion" })

vim.keymap.set("n", "<Tab>", function()
	local Nes = require("sidekick.nes")
	if not Nes.have() then
		return "<Tab>"
	end

	-- Jump schedules the cursor move; selabel.select also schedules, so the
	-- picker opens after the cursor lands (relative = "cursor").
	Nes.jump()

	require("config.selabel").select({ "Accept", "Dismiss" }, { "a", "d" }, "Copilot next edit", function(choice)
		if choice == "Accept" then
			Nes.apply()
		elseif choice == "Dismiss" then
			Nes.clear()
		end
	end)

	return ""
end, { expr = true, silent = true, desc = "Jump to Copilot next edit" })

vim.keymap.set("n", "<M-n>", function()
	vim.notify("Requested Copilot next edit", vim.log.levels.INFO)
	require("sidekick.nes").update()
end, { desc = "Request Copilot next edit" })

-- Sidekick CLI: pick a context-aware prompt and paste it into Pi (no submit).
-- Visual mode: only prompts attached to a selection ({selection} / {this}).
-- Normal mode: only prompts that do not use selection context.
local prompt_label = {
	buffers = "b",
	changes = "c",
	class = "C",
	diagnostics = "d",
	diagnostics_all = "a",
	document = "m",
	explain = "e",
	file = "f",
	fix = "f",
	["function"] = "n",
	line = "l",
	optimize = "o",
	position = "p",
	quickfix = "q",
	review = "r",
	selection = "s",
	tests = "t",
}

vim.keymap.set({ "n", "x" }, "<M-p>", function()
	local selabel = require("config.selabel")
	local visual = vim.fn.mode():find("[vV\22]") ~= nil
	local prompts = {}

	for name, prompt in pairs(require("sidekick.config").cli.prompts) do
		local msg = type(prompt) == "table" and (prompt.msg or "") or tostring(prompt)
		local visual_prompt = msg:find("{selection}", 1, true) ~= nil
			or msg:find("{this}", 1, true) ~= nil
		if visual == visual_prompt then
			prompts[#prompts + 1] = name
		end
	end
	table.sort(prompts)

	local labels = {}
	for i, name in ipairs(prompts) do
		labels[i] = prompt_label[name] or name:sub(1, 1)
	end

	selabel.select(prompts, labels, "Prompt action", function(choice)
		if not choice then
			return
		end
		require("sidekick.cli").send({
			prompt = choice,
			name = "pi",
		})
	end)
end, { desc = "Sidekick prompt to Pi" })

vim.lsp.enable("copilot")
