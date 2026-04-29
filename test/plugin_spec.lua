local render = require('marklive.render')

local function test_config()
  return {
    render = {
      code_block = {
        language_styles = {
          default = { icon = '', fg = '#89B4FA' },
          js = { icon = '', fg = '#F7DF1E' },
        },
      },
    },
  }
end

local function render_code_block(lines, cursor_line)
  local namespace = vim.api.nvim_create_namespace('marklive_code_block_test')
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line or 2, 0 })

  render.code_block({
    bufnr = 0,
    namespace = namespace,
    config = test_config(),
    start_row = 0,
    start_col = 0,
    end_row = #lines,
    end_col = 0,
  })

  return namespace
end

local function virt_text_to_string(virt_text)
  local chunks = {}
  for _, chunk in ipairs(virt_text or {}) do
    table.insert(chunks, chunk[1])
  end
  return table.concat(chunks, '')
end

local function find_language_label(namespace, lang)
  local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    local text = virt_text_to_string(details and details.virt_text)
    if extmark[2] == 0 and extmark[3] == 0 and text:find(lang, 1, true) then
      return details, text
    end
  end

  return nil, ''
end

describe('code block language badge', function()
  before_each(function()
    vim.cmd('enew!')
  end)

  it('renders the language badge at the left edge', function()
    local namespace = render_code_block({ '```js', 'const user = "Yelog"', '```' })
    local details, text = find_language_label(namespace, 'js')

    assert.is_not_nil(details)
    assert.are.equal('overlay', details.virt_text_pos)
    assert.are_not.equal('right_align', details.virt_text_pos)
    assert.is_true(text:find('', 1, true) ~= nil)
  end)

  it('uses aliased language styles without changing the displayed language', function()
    local namespace = render_code_block({ '```javascript', 'const user = "Yelog"', '```' })
    local details, text = find_language_label(namespace, 'javascript')
    local hl = vim.api.nvim_get_hl(0, { name = 'MarkliveCodeblockLang_javascript', link = false })

    assert.is_not_nil(details)
    assert.is_true(text:find('javascript', 1, true) ~= nil)
    assert.is_true(text:find('', 1, true) ~= nil)
    assert.are.equal(0xf7df1e, hl.fg)
  end)

  it('hides the language badge when the cursor is on the opening fence', function()
    local namespace = render_code_block({ '```python', 'print("Hello World")', '```' }, 1)
    local details = find_language_label(namespace, 'python')

    assert.is_nil(details)
  end)
end)
