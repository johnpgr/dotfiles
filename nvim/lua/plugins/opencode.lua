return {
    "NickvanDyke/opencode.nvim",
    dependencies = {
        -- Recommended for `ask()` and `select()`.
        -- Required for `snacks` provider.
        ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
        -- { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
        ---@type opencode.Opts
        vim.g.opencode_opts = {
            provider = {
                enabled = "tmux",
            },
            prompts = {
                holefill = {
                    prompt = "Complete the TODO placeholder in @this - replace the TODO comment with the actual implementation. Respond with code only.",
                    submit = true,
                },
                refactor = {
                    prompt = [[Refactor @buffer

The refactoring instructions are in the comments at the end of the file.

Before making changes:
1. Read the full file to find and understand the instruction comments at the bottom
2. Identify and read any imported modules, types, or dependencies
3. Check for other usages in the codebase if refactoring a function/class
4. Apply the refactoring as instructed
5. Remove the instruction comments after applying the refactoring]],
                    submit = true,
                },
            },
        }

        -- Generate commit message using opencode CLI and insert at cursor
        -- Configure model for commit message generation (use a fast/cheap model)
        local commit_message_model = "github-copilot/claude-haiku-4.5"

        local function generate_commit_message()
            local buf = vim.api.nvim_get_current_buf()
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            row = row - 1 -- 0-indexed

            -- First, get the staged diff synchronously (use --no-ext-diff to bypass difftastic)
            local diff_result = vim.system(
                { "git", "diff", "--cached", "--no-ext-diff", "--no-color" },
                { text = true }
            )
                :wait()

            if diff_result.code ~= 0 then
                vim.notify("Failed to get staged changes", vim.log.levels.ERROR)
                return
            end

            local diff_output = diff_result.stdout or ""
            if diff_output == "" then
                vim.notify("No staged changes found", vim.log.levels.WARN)
                return
            end

            vim.notify("Generating commit message...", vim.log.levels.INFO)

            -- Build the prompt with the diff included directly (avoids tool calls)
            local prompt = [[Write a commit message for the following change with commitizen convention. Keep the title under 50 characters and wrap the body at 72 characters. Include a descriptive body explaining what changed and why. Output ONLY the commit message, no markdown, no code blocks, no explanation.

Here are the staged changes:

]] .. diff_output

            -- Use vim.system for better argument handling
            vim.system(
                { "opencode", "run", "--format", "json", "--model", commit_message_model, prompt },
                { text = true },
                function(result)
                    vim.schedule(function()
                        if result.code ~= 0 then
                            vim.notify(
                                "Failed to generate commit message: " .. (result.stderr or ""),
                                vim.log.levels.ERROR
                            )
                            return
                        end

                        -- Parse JSON lines and extract text parts
                        local text_parts = {}
                        for line in (result.stdout or ""):gmatch("[^\r\n]+") do
                            local ok, parsed = pcall(vim.json.decode, line)
                            if ok and parsed.type == "text" and parsed.part and parsed.part.text then
                                table.insert(text_parts, parsed.part.text)
                            end
                        end

                        if #text_parts == 0 then
                            vim.notify("No commit message generated", vim.log.levels.WARN)
                            return
                        end

                        local commit_msg = table.concat(text_parts, "")
                        -- Trim whitespace
                        commit_msg = commit_msg:gsub("^%s+", ""):gsub("%s+$", "")
                        local lines = vim.split(commit_msg, "\n", { plain = true })

                        -- Insert at cursor position in the original buffer
                        if vim.api.nvim_buf_is_valid(buf) then
                            vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
                            vim.notify("Commit message generated", vim.log.levels.INFO)
                        else
                            vim.notify("Buffer no longer valid", vim.log.levels.ERROR)
                        end
                    end)
                end
            )
        end

        -- Required for `opts.events.reload`.
        vim.o.autoread = true

        vim.keymap.set({ "n", "x" }, "<leader>ca", function()
            require("opencode").ask("", { submit = true })
        end, { desc = "Ask opencode" })
        vim.keymap.set({ "n", "x" }, "<M-X>", function()
            require("opencode").select()
        end, { desc = "Execute opencode action…" })

        vim.keymap.set({ "n", "x" }, "<leader>cx", function()
            require("opencode").select()
        end, { desc = "Execute opencode action…" })

        vim.keymap.set({ "n", "t" }, "<C-A-b>", function()
            require("opencode").toggle()
        end, { desc = "Toggle opencode" })

        vim.keymap.set({ "n", "t" }, "<leader>cc", function()
            require("opencode").toggle()
        end, { desc = "Toggle opencode" })

        vim.keymap.set({ "n", "x" }, "go", function()
            return require("opencode").operator("@this ")
        end, { expr = true, desc = "Add range to opencode" })
        vim.keymap.set("n", "goo", function()
            return require("opencode").operator("@this ") .. "_"
        end, { expr = true, desc = "Add line to opencode" })

        vim.keymap.set("n", "<C-PageUp>", function()
            require("opencode").command("session.half.page.up")
        end, { desc = "opencode half page up" })
        vim.keymap.set("n", "<C-PageDown>", function()
            require("opencode").command("session.half.page.down")
        end, { desc = "opencode half page down" })
    end,
}
