local M = {}

local sqlite = require("sqlite.db")
local tbl = require("sqlite.tbl")
local strftime = sqlite.lib.strftime
local uri = vim.fn.stdpath("data") .. "/nvim_config.db"

---@class YankEntry
---@field id number: unique id
---@field content string: yanked content
---@field created_at number: when it was first yanked
---@field last_used_at number: when it was last used
---@field usage_count number: how many times it was used
---@field line_count number: number of lines in content
---@field char_count number: number of characters

---@class YankTbl: sqlite_tbl
local entries_table = tbl("yank_entries", {
    id = true, -- same as { type = "integer", required = true, primary = true }
    content = { "text", required = true },
    created_at = { "integer", default = strftime("%s", "now") },
    last_used_at = { "integer", default = strftime("%s", "now") },
    usage_count = { "integer", default = 0 },
    line_count = { "integer", default = 1 },
    char_count = { "integer", default = 0 },
})

---@class YankDB: sqlite_db
---@field entries YankTbl
M.db = sqlite({ uri = uri, entries = entries_table })

---Add a yank entry
---@param content string
function entries_table:add(content)
    if not content or content == "" or content == "\n" then
        return
    end

    local lines = vim.split(content, "\n", { plain = true })
    local line_count = #lines
    local char_count = #content
    local created_at = os.time()

    -- Check if exact content exists in recent entries
    local existing = entries_table:get({
        where = { content = content },
        limit = 1,
    })

    if #existing > 0 then
        -- Update existing entry
        local entry = existing[1]
        if (created_at - entry.created_at) < 300 then
            -- Too recent, skip
            return entry.id
        else
            -- Update last_used_at and usage_count
            entries_table:update({
                where = { id = entry.id },
                set = {
                    last_used_at = created_at,
                    usage_count = entry.usage_count + 1,
                },
            })
            return entry.id
        end
    else
        -- Insert new entry
        local id = entries_table:insert({
            content = content,
            created_at = created_at,
            last_used_at = created_at,
            usage_count = 0,
            line_count = line_count,
            char_count = char_count,
        })

        -- Keep only last 100 entries
        local total_count = entries_table:count()
        if total_count > 100 then
            local oldest = entries_table:get({
                order_by = { asc = "created_at" },
                limit = total_count - 100,
            })

            for _, entry in ipairs(oldest) do
                entries_table:remove({ id = entry.id })
            end
        end

        return id
    end
end

---Get all yank entries with time-weighted scoring
function entries_table:get_with_score(q)
    local items = entries_table:get(q or {})
    local current_time = os.time()

    -- Add scoring to each item
    for _, entry in ipairs(items) do
        -- Calculate age bonus (newer entries get higher scores)
        local age_hours = (current_time - entry.created_at) / 3600
        local age_bonus = math.max(0, 100 - age_hours)

        -- Calculate usage score based on usage_count and recency
        local usage_score = entry.usage_count * 10

        -- Bonus for recently used items
        local last_used_hours = (current_time - entry.last_used_at) / 3600
        local recency_bonus = math.max(0, 50 - last_used_hours)

        -- Combine all scores
        entry.score = age_bonus + usage_score + recency_bonus
    end

    -- Sort by combined score (highest first)
    table.sort(items, function(a, b)
        return (a.score or 0) > (b.score or 0)
    end)

    return items
end

---Record usage of a yank entry
---@param id number
function entries_table:use(id)
    local current_time = os.time()
    local entry = entries_table:get({ where = { id = id }, limit = 1 })[1]

    if entry then
        entries_table:update({
            where = { id = id },
            set = {
                last_used_at = current_time,
                usage_count = entry.usage_count + 1,
            },
        })
    end
end

---Delete a yank entry
---@param id string
function entries_table:delete_entry(id)
    return entries_table:remove({ id = id })
end

function M.open_yank_history()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local themes = require("telescope.themes")
    local sorters = require("telescope.config")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local opts = require("utils").default_picker_config

    local origin_buf = vim.api.nvim_get_current_buf()
    local origin_win = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(origin_win)
    local row, col = cursor[1], cursor[2]
    local ns = vim.api.nvim_create_namespace("YankHistoryPreview")

    local function clear_preview()
        if vim.api.nvim_buf_is_loaded(origin_buf) then
            vim.api.nvim_buf_clear_namespace(origin_buf, ns, 0, -1)
        end
    end

    -- Move data fetching inside this function so it's refreshed each time
    local history = entries_table:get_with_score({
        order_by = { desc = "created_at" },
        limit = 100,
    })

    if #history == 0 then
        vim.notify("No yank history found", vim.log.levels.WARN)
        return
    end

    -- Convert to format expected by telescope
    local registers = {}
    for _, entry in ipairs(history) do
        local display_content = entry.content:gsub("\n", "\\n")
        if #display_content > 80 then
            display_content = display_content:sub(1, 80) .. "..."
        end

        local time_str = os.date("%H:%M", entry.created_at)
        local usage_info = entry.usage_count
                and entry.usage_count > 0
                and string.format(" (used %dx)", entry.usage_count)
            or ""
        local display = string.format("[%s]%s %s", time_str, usage_info, display_content)

        table.insert(registers, {
            content = entry.content,
            display = display,
            timestamp = entry.created_at,
            line_count = entry.line_count or 1,
            id = entry.id,
            score = entry.score or 0,
        })
    end

    local finder = finders.new_table({
        results = registers,
        entry_maker = function(entry)
            return {
                value = entry.content,
                display = entry.display,
                ordinal = entry.display,
                entry = entry,
            }
        end,
    })
    local sorter = sorters.values.generic_sorter({})

    pickers
        .new({}, {
            finder = finder,
            sorter = sorter,
            attach_mappings = function(prompt_bufnr, map)
                local function update_preview()
                    if not vim.api.nvim_buf_is_loaded(origin_buf) then
                        return
                    end
                    clear_preview()
                    local sel = action_state.get_selected_entry()
                    if not sel or not sel.value then
                        return
                    end
                    local content = sel.value
                    if type(content) ~= "string" then
                        return
                    end
                    local lines = vim.split(content, "\n", { plain = true })
                    if #lines == 0 then
                        return
                    end

                    if #lines == 1 then
                        vim.api.nvim_buf_set_extmark(origin_buf, ns, row - 1, col, {
                            virt_text = { { lines[1], "Comment" } },
                            virt_text_pos = "inline",
                            hl_mode = "combine",
                        })
                    else
                        local virt_lines = {}
                        for i = 2, #lines do
                            virt_lines[#virt_lines + 1] = { { lines[i], "Comment" } }
                        end
                        vim.api.nvim_buf_set_extmark(origin_buf, ns, row - 1, col, {
                            virt_text = { { lines[1], "Comment" } },
                            virt_text_pos = "inline",
                            virt_lines = virt_lines,
                            hl_mode = "combine",
                        })
                    end
                end

                local function move_next()
                    actions.move_selection_next(prompt_bufnr)
                    update_preview()
                end
                local function move_prev()
                    actions.move_selection_previous(prompt_bufnr)
                    update_preview()
                end

                map("i", "<Down>", move_next)
                map("i", "<C-n>", move_next)
                map("i", "<Up>", move_prev)
                map("i", "<C-p>", move_prev)
                map("n", "j", move_next)
                map("n", "k", move_prev)

                -- Add delete mapping
                local function delete_entry()
                    local selection = action_state.get_selected_entry()
                    if not selection or not selection.entry.id then
                        return
                    end

                    entries_table:delete_entry(selection.entry.id)
                    move_next()
                    actions.close(prompt_bufnr)
                    M.open_yank_history()
                end

                map("i", "<C-d>", delete_entry)
                map("n", "D", delete_entry)

                vim.defer_fn(update_preview, 20)

                actions.select_default:replace(function()
                    clear_preview()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection then
                        local content = selection.value
                        local lines = vim.split(content, "\n")
                        local cur = vim.api.nvim_win_get_cursor(0)
                        local r, c = cur[1], cur[2]

                        -- Record usage
                        entries_table:use(selection.entry.id)

                        if #lines == 1 then
                            local current_line = vim.api.nvim_get_current_line()
                            local new_line = current_line:sub(1, c) .. content .. current_line:sub(c + 1)
                            vim.api.nvim_set_current_line(new_line)
                            vim.api.nvim_win_set_cursor(0, { r, c + #content })
                        else
                            local current_line = vim.api.nvim_get_current_line()
                            local before = current_line:sub(1, c)
                            local after = current_line:sub(c + 1)

                            lines[1] = before .. lines[1]
                            lines[#lines] = lines[#lines] .. after

                            vim.api.nvim_buf_set_lines(0, r - 1, r, false, lines)
                            vim.api.nvim_win_set_cursor(0, { r + #lines - 1, #lines[#lines] - #after })
                        end
                    end
                end)

                -- Clear preview when the picker buffer is wiped
                vim.api.nvim_create_autocmd("BufWipeout", {
                    buffer = prompt_bufnr,
                    once = true,
                    callback = clear_preview,
                })

                return true
            end,
        })
        :find()
end

return M
