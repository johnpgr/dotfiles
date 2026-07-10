vim.pack.add({ 'https://github.com/stevearc/oil.nvim' })

local permission_hlgroups = {
  ['-'] = 'NonText',
  ['r'] = 'DiagnosticSignWarn',
  ['w'] = 'DiagnosticSignError',
  ['x'] = 'DiagnosticSignOk',
}
local columns = {}

if vim.g.icons_enabled then
  table.insert(columns, { 'icon', add_padding = false })
end

local function oil_action_open_file()
  local oil = require('oil')
  local entry = oil.get_cursor_entry()
  local cwd = oil.get_current_dir()

  if not entry then
    return
  end

  local cmd = (vim.fn.has('mac') == 1) and 'open' or (vim.fn.has('win32') == 1) and 'start' or 'xdg-open'

  local full_path = cwd .. entry.name
  vim.fn.jobstart({ cmd, full_path }, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify('Failed to open file: ' .. entry.name, vim.log.levels.ERROR)
      end
    end,
  })
end

local function oil_action_run_cmd_on_file()
  local oil = require('oil')
  local entry = oil.get_cursor_entry()
  local cwd = oil.get_current_dir()

  if not entry then
    return
  end

  vim.ui.input({ prompt = 'Enter command: ' }, function(cmd)
    if not cmd then
      return
    end

    local full_path = cwd .. entry.name

    local function show_terminal(cmd_array)
      vim.cmd('botright new')
      vim.fn.jobstart(cmd_array, {
        on_exit = function(_, code)
          if code ~= 0 then
            vim.notify('Command exited with code: ' .. code, vim.log.levels.WARN)
          end
        end,
        term = true,
      })
      vim.cmd('startinsert')
    end

    if cmd and cmd ~= '' then
      local command_string = cmd .. ' ' .. vim.fn.shellescape(full_path)
      show_terminal({ 'sh', '-c', command_string })
    else
      local stat = vim.uv.fs_stat(full_path)
      if stat and stat.type == 'file' then
        if bit.band(stat.mode, tonumber('100', 8)) > 0 then
          show_terminal({ full_path })
        else
          vim.ui.select({ 'Yes', 'No' }, {
            prompt = 'File is not executable. Make it executable and run?',
          }, function(choice)
            if choice == 'Yes' then
              local chmod_res = vim.system({ 'chmod', '+x', full_path }):wait()
              if chmod_res.code == 0 then
                vim.notify('Made file executable: ' .. entry.name)
                show_terminal({ full_path })
              else
                vim.notify('Failed to make file executable: ' .. entry.name, vim.log.levels.ERROR)
              end
            else
              vim.notify('Aborted execution of: ' .. entry.name)
            end
          end)
        end
      else
        vim.notify('Not a valid file: ' .. entry.name, vim.log.levels.WARN)
      end
    end
  end)
end

require('oil').setup({
  lsp_file_methods = { enabled = vim.version().minor ~= 12 },
  columns = columns,
  skip_confirm_for_simple_edits = true,
  view_options = {
    show_hidden = false,
  },
  keymaps = {
    ['q'] = function()
      vim.api.nvim_win_close(0, true)
    end,
    ['<RightMouse>'] = '<LeftMouse><cmd>lua require(\'oil.actions\').select.callback()<CR>',
    ['?'] = 'actions.show_help',
    ['<CR>'] = function()
      local oil = require('oil')
      local entry = oil.get_cursor_entry()
      if not entry then
        return
      end
      local dir = oil.get_current_dir()
      if not dir then
        return
      end
      local full_path = dir .. entry.name
      local stat = vim.uv.fs_stat(full_path)
      if stat and stat.type == 'directory' then
        oil.select()
        return
      end

      local current_win = vim.api.nvim_get_current_win()
      local current_pos = vim.api.nvim_win_get_position(current_win)
      local current_row = current_pos[1]
      local current_col = current_pos[2]
      local current_width = vim.api.nvim_win_get_width(current_win)
      local above_win = nil
      local nearest_bottom = -1

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= current_win then
          local pos = vim.api.nvim_win_get_position(win)
          local row = pos[1]
          local col = pos[2]
          local height = vim.api.nvim_win_get_height(win)
          local width = vim.api.nvim_win_get_width(win)
          local bottom = row + height
          local overlaps_column = col < current_col + current_width and col + width > current_col
          if overlaps_column and bottom <= current_row and bottom > nearest_bottom then
            above_win = win
            nearest_bottom = bottom
          end
        end
      end

      if above_win then
        local above_buf = vim.api.nvim_win_get_buf(above_win)
        local above_is_empty = vim.api.nvim_buf_get_name(above_buf) == ''
          and vim.api.nvim_get_option_value('buftype', { buf = above_buf }) == ''
          and not vim.api.nvim_get_option_value('modified', { buf = above_buf })
          and vim.api.nvim_buf_line_count(above_buf) == 1
          and vim.api.nvim_buf_get_lines(above_buf, 0, 1, false)[1] == ''

        if above_is_empty then
          vim.api.nvim_win_close(current_win, true)
          vim.api.nvim_set_current_win(above_win)
          vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
          return
        end
      end

      vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
    end,
    ['<C-v>'] = { 'actions.select', opts = { vertical = true } },
    ['<C-x>'] = { 'actions.select', opts = { horizontal = true } },
    ['<F1>'] = oil_action_run_cmd_on_file,
    ['<F5>'] = 'actions.refresh',
    ['~'] = { 'actions.cd', opts = { scope = 'tab' }, mode = 'n' },
    ['<BS>'] = { 'actions.parent', mode = 'n' },
    ['-'] = { 'actions.parent', mode = 'n' },
    ['H'] = 'actions.toggle_hidden',
    ['<leader>o'] = oil_action_open_file,
  },
  confirmation = { border = 'single' },
  win_options = {
    winbar = '%!v:lua.get_oil_winbar()',
    foldcolumn = vim.o.foldcolumn,
  },
  use_default_keymaps = false,
  watch_for_changes = true,
  constrain_cursor = 'name',
})
