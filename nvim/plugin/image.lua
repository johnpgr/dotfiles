local term = os.getenv('TERM')
local is_kitty = term == 'xterm-kitty' or term == 'xterm-ghostty' or term == 'wezterm'
local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0

if image_enabled then
  local hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.bmp' }

  local lazy_pack = require('lazy_pack')

  local load = lazy_pack.loader({ 'https://github.com/3rd/image.nvim' }, function()
    require('image').setup({
      backend = 'kitty',
      processor = 'magick_cli',
      integrations = {
        markdown = { only_render_image_at_cursor = true },
      },
      hijack_file_patterns = hijack_file_patterns,
    })
  end)

  lazy_pack.on_event(
    { 'BufReadPre', 'BufNewFile', 'FileType' },
    load,
    { pattern = vim.list_extend(vim.deepcopy(hijack_file_patterns), { 'markdown', 'norg', 'typst' }) }
  )
end
