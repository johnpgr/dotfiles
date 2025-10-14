local M = {}

local config_db_uri = require("utils").config_db_uri
local sqlite = require("sqlite.db")
local tbl = require("sqlite.tbl")

local colorscheme_tbl = tbl("colorscheme", {
    id = { "integer", primary = true },
    name = { "text", required = true, unique = true },
    updated_at = { "integer", default = sqlite.lib.strftime("%s", "now") },
})

M.db = sqlite({
    uri = config_db_uri,
    colorscheme = colorscheme_tbl,
})

---@param colors_name string
function M.persist_colorscheme(colors_name)
    local existing = colorscheme_tbl:get({ where = { name = colors_name }, limit = 1 })
    if #existing > 0 then
        colorscheme_tbl:update({
            where = { id = existing[1].id },
            set = { updated_at = os.time() },
        })
    else
        colorscheme_tbl:insert({ name = colors_name, updated_at = os.time() })
    end
end

-- Load persisted colorscheme
function M.load_persisted_colorscheme()
    local recent = colorscheme_tbl:get({
        order_by = { desc = "updated_at" },
        limit = 1,
    })
    if #recent > 0 then
        pcall(vim.cmd.colorscheme, recent[1].name)
    end

    vim.cmd([[
        hi VertSplit ctermfg=250
        hi! link MsgSeparator WinSeparator
        hi! link PmenuExtra Pmenu
        hi Operator guibg=none
        hi MatchParen guifg=bg
        hi WinBar guibg=none
        hi WinBarNC guibg=none
        hi NormalFloat guibg=none
        hi FloatBorder guibg=none
        hi TelescopeBorder guibg=none
        hi WhichKeyBorder guibg=none
        hi FoldColumn ctermbg=none guibg=none
    ]])
end

return M
