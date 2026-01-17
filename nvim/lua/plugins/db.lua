local function toggle_dbui_tab()
    -- Find a tab that has DBUI open (by filetype or buffer name)
    local dbui_tab = nil
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.api.nvim_buf_get_option(buf, "filetype")
            local name = vim.api.nvim_buf_get_name(buf) or ""
            if ft == "dbui" or name:match("DBUI") or name:match("dbui") then
                dbui_tab = tab
                break
            end
        end
        if dbui_tab then
            break
        end
    end

    if dbui_tab then
        -- Close the tab that contains DBUI
        vim.api.nvim_set_current_tabpage(dbui_tab)
        vim.cmd("tabclose")
    else
        -- Open DBUI in a new tab
        vim.cmd("tabnew")
        vim.cmd("DBUI")
    end
end
-- Database UI
return {
    {
        "tpope/vim-dadbod",
        cmd = "DBUI",
        dependencies = {
            "kristijanhusak/vim-dadbod-completion",
            "kristijanhusak/vim-dadbod-ui",
        },
    },
    { "kristijanhusak/vim-dadbod-completion", lazy = true },
    {
        "kristijanhusak/vim-dadbod-ui",
        keys = {
            { "<leader>ub", toggle_dbui_tab, desc = "DBUI" },
            { "<leader>ua", "<cmd>DBUIAddConnection<cr>", desc = "Add new connection" },
        },
        lazy = true,
    },
}
