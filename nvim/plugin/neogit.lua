local term = os.getenv('TERM')
local is_kitty = term == 'xterm-kitty' or term == 'xterm-ghostty' or term == 'wezterm'

function _G.dotfiles_neogit_checkout_completion(arg_lead)
  local options = _G.dotfiles_neogit_checkout_options or {}
  if arg_lead == '' then
    return options
  end

  local matches = {}
  local needle = arg_lead:lower()
  for _, option in ipairs(options) do
    if option:lower():find(needle, 1, true) then
      table.insert(matches, option)
    end
  end

  return vim.tbl_isempty(matches) and options or matches
end

local function patch_neogit_checkout_commit()
  local actions = require('neogit.popups.branch.actions')
  local worktree_actions = require('neogit.popups.worktree.actions')
  if actions.__dotfiles_checkout_commit_patch then
    return
  end

  local function select_ref(prompt, target, options)
    local previous_options = _G.dotfiles_neogit_checkout_options
    _G.dotfiles_neogit_checkout_options = options
    local selected = require('neogit.lib.input').get_user_input(prompt, {
      completion = 'customlist,v:lua.dotfiles_neogit_checkout_completion',
      prepend = '<Tab><Tab>',
    })
    _G.dotfiles_neogit_checkout_options = previous_options
    return selected
  end

  local function context_ref_options(popup, target)
    local git = require('neogit.lib.git')
    local util = require('neogit.lib.util')
    return util.deduplicate(util.merge({
      target,
      popup.state.env.ref_name,
    }, popup.state.env.commits or {}, git.refs.list_branches(), git.refs.list_tags(), git.refs.heads()))
  end

  local original = actions.checkout_branch_revision
  actions.checkout_branch_revision = function(popup)
    local commits = popup.state.env.commits
    local target = commits and #commits == 1 and commits[1] or nil
    if not target then
      return original(popup)
    end

    local git = require('neogit.lib.git')
    local event = require('neogit.lib.event')
    local notification = require('neogit.lib.notification')

    local selected = select_ref('Checkout', target, context_ref_options(popup, target))
    if not selected then
      return
    end

    local result = git.branch.checkout(selected, popup:get_arguments())
    if result:failure() then
      notification.error(table.concat(result.stderr, '\n'))
      return
    end

    event.send('BranchCheckout', { branch_name = selected })
    notification.info('Checked out ' .. selected)
  end

  local original_worktree = worktree_actions.checkout_worktree
  worktree_actions.checkout_worktree = function(popup)
    local commits = popup and popup.state.env.commits
    local target = commits and #commits == 1 and commits[1] or nil
    if not target then
      return original_worktree(popup)
    end

    local git = require('neogit.lib.git')
    local input = require('neogit.lib.input')
    local status = require('neogit.buffers.status')
    local notification = require('neogit.lib.notification')
    local event = require('neogit.lib.event')

    local selected = select_ref('Checkout', target, context_ref_options(popup, target))
    if not selected then
      return
    end

    local path = input.get_user_input(("Checkout '%s' in new worktree"):format(selected), {
      completion = 'dir',
      prepend = vim.fs.normalize(vim.uv.cwd() .. '/..') .. '/',
    })
    if not path then
      return
    end

    if vim.uv.fs_stat(path) then
      path = vim.fs.joinpath(path, selected)
    end

    local cwd = vim.uv.cwd()
    local success, err = git.worktree.add(selected, path)
    if success then
      notification.info('Added worktree')

      if status.is_open() then
        status.instance():chdir(path)
      end

      event.send('WorktreeCreate', {
        old_cwd = cwd,
        new_cwd = path,
        copy_if_present = function(filename, callback)
          if not cwd then
            return
          end

          local source = vim.fs.joinpath(cwd, filename)
          local destination = vim.fs.joinpath(path, filename)
          if vim.uv.fs_stat(source) and not vim.uv.fs_stat(destination) then
            local ok = vim.uv.fs_copyfile(source, destination)
            if ok and type(callback) == 'function' then
              callback()
            end
          end
        end,
      })
    else
      notification.error(err)
    end
  end

  actions.__dotfiles_checkout_commit_patch = true
end

local lazy_pack = require('lazy_pack')

local load = lazy_pack.loader({ 'https://github.com/NeogitOrg/neogit' }, function()
  patch_neogit_checkout_commit()

  require('neogit').setup({
    graph_style = is_kitty and 'kitty' or 'ascii',
    commit_editor = {
      kind = 'vsplit',
      show_staged_diff = false,
    },
    console_timeout = 5000,
    auto_show_console = false,
    integrations = {
      diffview = true,
      mini_pick = false,
      telescope = false,
      fzf_lua = false,
      snacks = false,
    },
  })
end)

load = lazy_pack.on_command(load, { 'Neogit', 'NeogitLogCurrent' })

lazy_pack.on_keys(load, {
  { mode = 'n', lhs = '<M-g>', desc = 'Git status', fn = function()
    require('neogit').open({ kind = 'split' })
  end },
  { mode = 'n', lhs = '<leader>gg', desc = 'Git status', fn = function()
    require('neogit').open({ kind = 'split' })
  end },
  { mode = 'n', lhs = '<leader>gc', desc = 'Git commit', fn = function()
    require('neogit.buffers.commit_view').new('HEAD'):open('replace')
  end },
  { mode = 'n', lhs = '<leader>gb', desc = 'Git branch', fn = function()
    vim.cmd('Neogit branch')
  end },
  { mode = 'n', lhs = '<leader>gL', desc = 'Git log', fn = function()
    vim.cmd('NeogitLogCurrent')
  end },
})
