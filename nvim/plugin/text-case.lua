vim.pack.add({ 'https://github.com/johmsalas/text-case.nvim' })

require('textcase').setup({ prefix = 'tc' })

local conversions = {
  { label = 'camelCase',       key = 'c', method = 'to_camel_case' },
  { label = 'PascalCase',      key = 'p', method = 'to_pascal_case' },
  { label = 'snake_case',      key = 's', method = 'to_snake_case' },
  { label = 'dash-case',       key = 'd', method = 'to_dash_case' },
  { label = 'CONSTANT_CASE',   key = 'n', method = 'to_constant_case' },
  { label = 'UPPER CASE',      key = 'u', method = 'to_upper_case' },
  { label = 'lower case',      key = 'l', method = 'to_lower_case' },
  { label = 'Title Case',      key = 't', method = 'to_title_case' },
  { label = 'dot.case',        key = '.', method = 'to_dot_case' },
  { label = 'Title-Dash Case', key = 'T', method = 'to_title_dash_case' },
  { label = 'Phrase case',     key = 'P', method = 'to_phrase_case' },
}

local function pick_case()
  vim.ui.select(conversions, {
    prompt = 'Text case',
    format_item = function(item)
      return string.format('(%s) %s', item.key, item.label)
    end,
  }, function(choice)
    if choice then
      require('textcase').quick_replace(choice.method)
    end
  end)
end

vim.keymap.set({ 'n', 'x' }, '<leader>tc', pick_case, { desc = 'Text case conversion' })
