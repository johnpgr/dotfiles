local ignored_ls = {
    "opencode",
    "copilot",
}

-- Statusline
local function lsp_status()
    local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
    if #attached_clients == 0 then
        return ""
    end
    local names = vim.iter(attached_clients)
        :filter(function(client)
            return not vim.tbl_contains(ignored_ls, client.name)
        end)
        :map(function(client)
            local name = client.name:gsub("language.server", "ls")
            return name
        end)
        :totable()
    if #names == 0 then
        return ""
    end
    return "[" .. table.concat(names, ", ") .. "]"
end

function _G.statusline()
    return table.concat({
        "%f",
        "%h%w%m%r",
        "%=",
        lsp_status(),
        " %-14(%l,%c%V%)",
        "%P",
    }, " ")
end

vim.o.statusline = "%{%v:lua._G.statusline()%}"
