-- Oil winbar
function _G.get_oil_winbar()
    local result = ""
    local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winid)

    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ~= "oil" then
        return result
    end

    local dir = require("oil").get_current_dir(bufnr)
    if dir then
        dir = dir:len() > 1 and dir:gsub("/$", "") or dir
        result = dir .. ":"
    else
        result = vim.api.nvim_buf_get_name(bufnr)
    end

    return result
end

-- Oil.nvim
return {
    "stevearc/oil.nvim",
    enabled = false,
    lazy = false,
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

        -- local function oil_action_run_cmd_on_file()
        --     local oil = require("oil")
        --     local entry = oil.get_cursor_entry()
        --     local cwd = oil.get_current_dir()
        --
        --     if not entry then
        --         return
        --     end
        --
        --     vim.ui.input({ prompt = "Enter command: " }, function(cmd)
        --         if not cmd then
        --             return
        --         end
        --
        --         local full_path = cwd .. entry.name
        --
        --         local function show_terminal(cmd_array)
        --             vim.cmd("botright new")
        --             vim.fn.jobstart(cmd_array, {
        --                 on_exit = function(_, code)
        --                     if code ~= 0 then
        --                         vim.notify("Command exited with code: " .. code, vim.log.levels.WARN)
        --                     end
        --                 end,
        --                 term = true,
        --             })
        --             vim.cmd("startinsert")
        --         end
        --
        --         if cmd and cmd ~= "" then
        --             local command_string = cmd .. " " .. vim.fn.shellescape(full_path)
        --             show_terminal({ "sh", "-c", command_string })
        --         else
        --             local stat = vim.uv.fs_stat(full_path)
        --             if stat and stat.type == "file" then
        --                 if bit.band(stat.mode, tonumber("100", 8)) > 0 then
        --                     show_terminal({ full_path })
        --                 else
        --                     vim.ui.select({ "Yes", "No" }, {
        --                         prompt = "File is not executable. Make it executable and run?",
        --                     }, function(choice)
        --                         if choice == "Yes" then
        --                             local chmod_res = vim.system({ "chmod", "+x", full_path }):wait()
        --                             if chmod_res.code == 0 then
        --                                 vim.notify("Made file executable: " .. entry.name)
        --                                 show_terminal({ full_path })
        --                             else
        --                                 vim.notify(
        --                                     "Failed to make file executable: " .. entry.name,
        --                                     vim.log.levels.ERROR
        --                                 )
        --                             end
        --                         else
        --                             vim.notify("Aborted execution of: " .. entry.name)
        --                         end
        --                     end)
        --                 end
        --             else
        --                 vim.notify("Not a valid file: " .. entry.name, vim.log.levels.WARN)
        --             end
        --         end
        --     end)
        -- end

        require("oil").setup({
            lsp_file_methods = {
                enabled = vim.version().minor ~= 12,
            },
            -- columns = {
            -- 	{
            -- 		"permissions",
            -- 		highlight = function(permission_str)
            -- 			local hls = {}
            -- 			for i = 1, #permission_str do
            -- 				local char = permission_str:sub(i, i)
            -- 				table.insert(hls, { permission_hlgroups[char], i - 1, i })
            -- 			end
            -- 			return hls
            -- 		end,
            -- 	},
            -- 	{ "size", highlight = "Special" },
            -- 	{ "mtime", highlight = "Number" },
            -- 	{
            -- 		"icon",
            -- 		add_padding = false,
            -- 	},
            -- },
            skip_confirm_for_simple_edits = true,
            keymaps = {
                ["q"] = "actions.close",
                ["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
                ["?"] = "actions.show_help",
                ["<CR>"] = "actions.select",
                ["<F5>"] = "actions.refresh",
                ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
                ["-"] = { "actions.parent", mode = "n" },
                ["<Left>"] = { "actions.parent", mode = "n" },
                ["<Right>"] = { "actions.select", mode = "n" },
                ["H"] = "actions.toggle_hidden",
            },
            confirmation = {
                border = "single",
            },
            win_options = {
                winbar = "%!v:lua.get_oil_winbar()",
                number = false,
                relativenumber = false,
            },
            use_default_keymaps = false,
            watch_for_changes = true,
            constrain_cursor = "name",
        })
    end,
}
