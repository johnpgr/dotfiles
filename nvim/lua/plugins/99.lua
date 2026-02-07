local function pick_99_model()
    local _99 = require("99")
    local result = vim.system({ "opencode", "models" }, { text = true }):wait()

    if result.code ~= 0 then
        vim.notify("Failed to load opencode models", vim.log.levels.ERROR)
        return
    end

    local models = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        if line ~= "" then
            table.insert(models, line)
        end
    end

    if #models == 0 then
        vim.notify("No opencode models found", vim.log.levels.WARN)
        return
    end

    local ok, pickers = pcall(require, "telescope.pickers")
    if not ok then
        vim.ui.select(models, { prompt = "99 model" }, function(choice)
            if choice then
                _99.set_model(choice)
                vim.notify("99 model: " .. choice, vim.log.levels.INFO)
            end
        end)
        return
    end

    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
        prompt_title = "99 model",
        finder = finders.new_table({ results = models }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                local model = selection and (selection.value or selection[1])
                if model then
                    _99.set_model(model)
                    vim.notify("99 model: " .. model, vim.log.levels.INFO)
                end
            end)
            return true
        end,
    }):find()
end

return {
    "ThePrimeagen/99",
    keys = {
        { "<leader>99", function() require("99").fill_in_function_prompt() end, desc = "99: Fill in function"},
        { "<leader>9f", function() require("99").fill_in_function() end, desc = "99: Fill in function"},
        {"<leader>9v", function() require("99").visual() end, mode = "v", desc = "99: Visual selection"},
        { "<leader>9s", function() require("99").stop_all_requests() end, desc = "99: Stop all requests"},
        { "<leader>9m", pick_99_model, desc = "99: Pick model" },
    },
    config = function()
        local _99 = require("99")

        -- For logging that is to a file if you wish to trace through requests
        -- for reporting bugs, i would not rely on this, but instead the provided
        -- logging mechanisms within 99.  This is for more debugging purposes
        local cwd = vim.uv.cwd()
        local basename = vim.fs.basename(cwd)
        _99.setup({
            logger = {
                level = _99.DEBUG,
                path = "/tmp/" .. basename .. ".99.debug",
                print_on_error = true,
            },

            --- A new feature that is centered around tags
            completion = {
                --- Defaults to .cursor/rules
                -- I am going to disable these until i understand the
                -- problem better.  Inside of cursor rules there is also
                -- application rules, which means i need to apply these
                -- differently
                -- cursor_rules = "<custom path to cursor rules>"

                --- A list of folders where you have your own SKILL.md
                --- Expected format:
                --- /path/to/dir/<skill_name>/SKILL.md
                ---
                --- Example:
                --- Input Path:
                --- "scratch/custom_rules/"
                ---
                --- Output Rules:
                --- {path = "scratch/custom_rules/vim/SKILL.md", name = "vim"},
                --- ... the other rules in that dir ...
                ---
                custom_rules = {
                    "scratch/custom_rules/",
                },

                --- What autocomplete do you use.  We currently only
                --- support cmp right now
                source = "blink",
            },

            --- WARNING: if you change cwd then this is likely broken
            --- ill likely fix this in a later change
            ---
            --- md_files is a list of files to look for and auto add based on the location
            --- of the originating request.  That means if you are at /foo/bar/baz.lua
            --- the system will automagically look for:
            --- /foo/bar/AGENT.md
            --- /foo/AGENT.md
            --- assuming that /foo is project root (based on cwd)
            md_files = {
                "AGENTS.md",
            },
        })
        _99.set_model("opencode/kimi-k2.5-free")
    end,
}
