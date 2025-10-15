-- Online lookup module - search text on various online providers
local M = {}

local config_db_uri = require("utils").config_db_uri
local sqlite = require("sqlite.db")
local tbl = require("sqlite.tbl")

-- SQLite table for provider usage tracking
local provider_usage_tbl = tbl("lookup_provider_usage", {
    id = { "integer", primary = true },
    provider_name = { "text", required = true, unique = true },
    usage_count = { "integer", default = 0 },
    last_used_at = { "integer", default = sqlite.lib.strftime("%s", "now") },
})

M.db = sqlite({
    uri = config_db_uri,
    lookup_provider_usage = provider_usage_tbl,
})

-- Provider URL definitions
-- Each provider can have multiple backends (URL templates or custom functions)
M.providers = {
    { name = "Google", urls = { "https://google.com/search?q=%s" } },
    { name = "Google Images", urls = { "https://www.google.com/images?q=%s" } },
    { name = "Kagi", urls = { "https://kagi.com/search?q=%s" } },
    { name = "DuckDuckGo", urls = { "https://duckduckgo.com/?q=%s" } },
    { name = "StackOverflow", urls = { "https://stackoverflow.com/search?q=%s" } },
    { name = "StackExchange", urls = { "https://stackexchange.com/search?q=%s" } },
    { name = "GitHub", urls = { "https://github.com/search?ref=simplesearch&q=%s" } },
    { name = "Sourcegraph", urls = { "https://sourcegraph.com/search?q=context:global+%s&patternType=literal" } },
    { name = "DevDocs.io", urls = { "https://devdocs.io/#q=%s" } },
    { name = "MDN", urls = { "https://developer.mozilla.org/en-US/search?q=%s" } },
    { name = "Wikipedia", urls = { "https://wikipedia.org/search-redirect.php?language=en&go=Go&search=%s" } },
    { name = "Youtube", urls = { "https://youtube.com/results?search_query=%s" } },
    { name = "Wolfram Alpha", urls = { "https://wolframalpha.com/input/?i=%s" } },
    { name = "Internet Archive", urls = { "https://web.archive.org/web/*/%s" } },
    { name = "Arch Wiki", urls = { "https://wiki.archlinux.org/index.php?search=%s" } },
    { name = "Arch Packages", urls = { "https://archlinux.org/packages/?q=%s" } },
    { name = "AUR", urls = { "https://aur.archlinux.org/packages?K=%s" } },
}

-- Filetype-specific provider suggestions
M.filetype_providers = {
    rust = { "Rust Docs", "GitHub", "StackOverflow" },
    python = { "Python Docs", "PyPI", "StackOverflow" },
    javascript = { "MDN", "npm", "StackOverflow" },
    typescript = { "MDN", "npm", "StackOverflow" },
    lua = { "Lua Docs", "GitHub", "StackOverflow" },
    go = { "Go Docs", "pkg.go.dev", "StackOverflow" },
}

-- Add language-specific providers
table.insert(M.providers, { name = "Rust Docs", urls = { "https://doc.rust-lang.org/std/?search=%s" } })
table.insert(M.providers, { name = "Python Docs", urls = { "https://docs.python.org/3/search.html?q=%s" } })
table.insert(M.providers, { name = "PyPI", urls = { "https://pypi.org/search/?q=%s" } })
table.insert(M.providers, { name = "npm", urls = { "https://www.npmjs.com/search?q=%s" } })
table.insert(M.providers, { name = "Lua Docs", urls = { "https://www.lua.org/manual/5.4/search.html?q=%s" } })
table.insert(M.providers, { name = "Go Docs", urls = { "https://golang.org/search?q=%s" } })
table.insert(M.providers, { name = "pkg.go.dev", urls = { "https://pkg.go.dev/search?q=%s" } })
table.insert(M.providers, { name = "crates.io", urls = { "https://crates.io/search?q=%s" } })

-- Increment provider usage count
local function increment_provider_usage(provider_name)
    local existing = provider_usage_tbl:get({ where = { provider_name = provider_name }, limit = 1 })
    if #existing > 0 then
        provider_usage_tbl:update({
            where = { id = existing[1].id },
            set = {
                usage_count = existing[1].usage_count + 1,
                last_used_at = os.time(),
            },
        })
    else
        provider_usage_tbl:insert({
            provider_name = provider_name,
            usage_count = 1,
            last_used_at = os.time(),
        })
    end
end

-- Get provider usage count
local function get_provider_usage(provider_name)
    local result = provider_usage_tbl:get({ where = { provider_name = provider_name }, limit = 1 })
    if #result > 0 then
        return result[1].usage_count
    end
    return 0
end

-- Sort providers by usage frequency
local function sort_providers_by_usage()
    local sorted = vim.deepcopy(M.providers)
    table.sort(sorted, function(a, b)
        local a_count = get_provider_usage(a.name)
        local b_count = get_provider_usage(b.name)
        if a_count ~= b_count then
            return a_count > b_count
        end
        -- If usage count is the same, sort alphabetically
        return a.name < b.name
    end)
    return sorted
end

-- Get text to search (visual selection or word under cursor)
local function get_search_text()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "" then
        -- Visual mode - get selected text
        vim.cmd("noau normal! \"vy\"")
        return vim.fn.getreg("v")
    else
        -- Normal mode - get word under cursor
        return vim.fn.expand("<cword>")
    end
end

-- URL encode a string
local function url_encode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- Open URL in browser
local function open_url(url)
    local open_cmd
    if vim.fn.has("mac") == 1 then
        open_cmd = "open"
    elseif vim.fn.has("unix") == 1 then
        open_cmd = "xdg-open"
    elseif vim.fn.has("win32") == 1 then
        open_cmd = "start"
    else
        vim.notify("Unable to determine browser open command", vim.log.levels.ERROR)
        return
    end

    vim.fn.jobstart({ open_cmd, url }, { detach = true })
end

-- Get provider using telescope picker (sorted by usage)
local function get_provider(query)
    -- Use telescope to select provider
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local themes = require("telescope.themes")

    local selected_provider = nil
    local co = coroutine.running()

    -- Get providers sorted by usage frequency
    local sorted_providers = sort_providers_by_usage()
    local theme = themes.get_ivy({
        previewer = false,
        borderchars = { " ", " ", " ", " ", " ", " ", " ", " " },
        layout_config = {
            height = 12,
        },
        results_title = false,
    })

    local picker = pickers.new(theme, {
        prompt_title = string.format("Search '%s' on:", query),
        finder = finders.new_table({
            results = sorted_providers,
            entry_maker = function(entry)
                local display_text = entry.name
                return {
                    value = entry,
                    display = display_text,
                    ordinal = entry.name,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                selected_provider = action_state.get_selected_entry().value
                actions.close(prompt_bufnr)
                if co then
                    coroutine.resume(co)
                end
            end)
            return true
        end,
    })

    picker:find()

    if co then
        coroutine.yield()
    end

    return selected_provider
end

-- Main search function
function M.search_online_select()
    local query = get_search_text()
    if not query or query == "" then
        vim.notify("No text to search", vim.log.levels.WARN)
        return
    end

    coroutine.wrap(function()
        local provider = get_provider(query)
        if not provider then
            return
        end

        -- Increment usage count for this provider
        increment_provider_usage(provider.name)

        local encoded_query = url_encode(query)
        if not encoded_query then
            vim.notify("Failed to encode query", vim.log.levels.ERROR)
            return
        end

        -- Use the first URL in the provider's URL list
        local url_template = provider.urls[1]
        local url = string.format(url_template, encoded_query)

        vim.notify(string.format("Searching for '%s' on %s", query, provider.name), vim.log.levels.INFO)
        open_url(url)
    end)()
end

return M
