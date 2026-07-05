local term = os.getenv('TERM')
local is_kitty = term == 'xterm-kitty' or term == 'xterm-ghostty' or term == 'wezterm'
local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0

if image_enabled then
  vim.pack.add({ 'https://github.com/3rd/image.nvim' })

  require('image').setup({
    backend = 'kitty',
    processor = 'magick_cli',
    integrations = {
      markdown = { only_render_image_at_cursor = true },
    },
    hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.bmp' },
  })
end
