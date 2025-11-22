-- Copilot plugins

local title_prompt = [[
Generate chat title in filepath-friendly format for:

```
%s
```

Output only the title and nothing else in your response. USE HYPHENS ONLY to separate words.
]]

local function format_display_name(filename)
    filename = filename:gsub("%.%w+$", "")
    return filename:gsub("%-", " "):gsub("^%w", string.upper)
end

local function parse_history_path(file)
    return vim.fn.fnamemodify(file, ":t:r")
end

local function generate_commit_message()
    vim.notify("Generating commit message...", vim.log.levels.INFO)
    require("CopilotChat").ask("/Commit", {
        headless = true,
        callback = function(res)
            local content = vim.trim(res.content)
            -- Extract from ```gitcommit ... ``` block
            local message = content:match("```gitcommit%s*\n(.-)```") or content
            local lines = vim.split(vim.trim(message), "\n")
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
            vim.notify("Commit message generated", vim.log.levels.INFO)
        end,
    })
end

local function quick_chat()
    local mode = vim.fn.mode()
    local buffer_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    local context = "Buffer:\n```\n" .. buffer_content .. "\n```"

    -- Add visual selection if in visual mode
    if mode:match("[vV\22]") then
        vim.cmd('normal! "vy')
        local selection = vim.fn.getreg("v")
        context = context .. "\n\nSelection:\n```\n" .. selection .. "\n```"
    end

    vim.ui.input({ prompt = "Quick chat: " }, function(input)
        if not input or input == "" then
            return
        end

        local full_prompt = input .. "\n\n" .. context

        require("CopilotChat").ask(full_prompt, {
            window = {
                layout = "float",
                relative = "cursor",
                width = 0.6,
                height = 0.6,
                row = 1,
                col = 0,
            },
        })
    end)
end

-- TODO: Add previewer to show the chat content
local function find_chat_history()
    require("telescope.builtin").find_files({
        prompt_title = "",
        cwd = require("CopilotChat").config.history_path,
        hidden = true,
        follow = true,
        find_command = { "rg", "--files", "--sortr=modified" },
        entry_maker = function(entry)
            local full_path = require("CopilotChat").config.history_path .. "/" .. entry
            ---@diagnostic disable-next-line: undefined-field
            local stat = vim.loop.fs_stat(full_path)
            local mtime = stat and stat.mtime.sec or 0
            local display_time = stat and os.date("%d-%m-%Y %H:%M", mtime) or "Unknown"
            local display_name = format_display_name(entry)
            return {
                value = entry,
                display = string.format("%s | %s", display_time, display_name),
                ordinal = string.format("%s %s", display_time, display_name),
                path = entry,
                index = -mtime,
            }
        end,
        attach_mappings = function(prompt_bufnr, map)
            require("telescope.actions").select_default:replace(function()
                require("telescope.actions").close(prompt_bufnr)
                local selection = require("telescope.actions.state").get_selected_entry()
                local path = selection.value
                local parsed = parse_history_path(path)
                vim.g.chat_title = parsed
                require("CopilotChat").load(parsed)
                require("CopilotChat").open()
            end)

            local function delete_history()
                local selection = require("telescope.actions.state").get_selected_entry()
                if not selection then
                    return
                end

                local full_path = require("CopilotChat").config.history_path .. "/" .. selection.value

                -- Confirm deletion
                vim.ui.select({ "Yes", "No" }, {
                    prompt = "Delete chat history: " .. format_display_name(selection.value) .. "?",
                    telescope = { layout_config = { width = 0.3, height = 0.3 } },
                }, function(choice)
                    if choice == "Yes" then
                        vim.fn.delete(full_path)
                        find_chat_history()
                    end
                end)
            end

            map("i", "<C-d>", delete_history)
            map("n", "D", delete_history)
            return true
        end,
    })
end

return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
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
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        cmd = { "CopilotChat", "CopilotChatToggle", "CopilotChatPrompts" },
        keys = {
            { "<leader>cc", "<cmd>CopilotChatToggle<cr>", desc = "Copilot chat" },
            { "<leader>cp", "<cmd>CopilotChatPrompts<cr>", desc = "Copilot chat prompts" },
            {
                "<leader>cx",
                function()
                    vim.g.chat_title = nil
                    require("CopilotChat").reset()
                end,
                desc = "Copilot chat reset",
            },
            { "<leader>ch", find_chat_history, desc = "Copilot chat history" },
            { "<leader>cm", generate_commit_message, desc = "Copilot commit message" },
            { "<leader>cq", quick_chat, mode = { "n", "v" }, desc = "Quick chat" },
        },

        config = function()
            require("CopilotChat").setup({
                callback = function(res)
                    if vim.g.chat_title then
                        vim.defer_fn(function()
                            require("CopilotChat").save(vim.g.chat_title)
                        end, 100)
                        return
                    end

                    require("CopilotChat").ask(title_prompt:format(res.content), {
                        headless = true,
                        model = "gpt-4.1",
                        callback = function(res2)
                            vim.g.chat_title = vim.trim(res2.content)
                            require("CopilotChat").save(vim.g.chat_title)
                        end,
                    })
                end,
                model = "gpt-4.1",
                chat_autocomplete = true,
                mappings = {
                    complete = {
                        insert = "",
                    },
                    reset = {
                        normal = "",
                        insert = "",
                    },
                },
            })

            local function get_working_directory_files()
                local files = {}
                local handle = io.popen("rg --files")
                if handle then
                    for file in handle:lines() do
                        local trigger = vim.fn.fnamemodify(file, ":t:r")
                        files[#files + 1] = {
                            trigger = trigger,
                            path = "> #file:" .. file,
                        }
                    end
                    handle:close()
                end
                return files
            end

            vim.api.nvim_create_autocmd("WinEnter", {
                pattern = "copilot-chat",
                callback = function()
                    vim.opt_local.foldcolumn = "0"
                    vim.opt_local.number = false
                    vim.opt_local.relativenumber = false
                    vim.opt_local.cursorline = false

                    local snippets = {}
                    for _, file_info in ipairs(get_working_directory_files()) do
                        snippets[#snippets + 1] = require("luasnip").snippet(
                            file_info.trigger,
                            { require("luasnip").text_node(file_info.path) }
                        )
                    end

                    require("luasnip.session.snippet_collection").clear_snippets("copilot-chat")
                    require("luasnip").add_snippets("copilot-chat", snippets)
                    vim.treesitter.start()
                end,
            })
        end,
    },
}

