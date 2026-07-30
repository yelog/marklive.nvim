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

local function render_markdown(lines)
  local marklive = require('marklive')
  local namespace = marklive.namespace
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = 'markdown'
  marklive.setup({ render_delay = 0 })
  marklive.render()
  vim.wait(50)
  return namespace
end

local function find_italic_extmarks(namespace)
  local italic_extmarks = {}
  local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
  for _, extmark in ipairs(extmarks) do
    local details = extmark[4]
    if details and details.hl_group == 'markdownItalic' and details.conceal == nil then
      table.insert(italic_extmarks, {
        row = extmark[2],
        col = extmark[3],
        end_col = details.end_col,
      })
    end
  end

  return italic_extmarks
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
    assert.are_not.equal(' ', text:sub(1, 1))
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

describe('heading marker indentation', function()
  before_each(function()
    vim.cmd('enew!')
  end)

  it('adds inline indentation before heading markers', function()
    local namespace = vim.api.nvim_create_namespace('marklive_heading_marker_test')
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '### Level 3 Heading' })

    render.heading_marker({
      bufnr = 0,
      namespace = namespace,
      hl_group = 'markdownH3Delimiter',
      icon = '󰉭',
      indent = 4,
      start_row = 0,
      start_col = 0,
      end_row = 0,
      end_col = 3,
    })

    local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
    local found_indent = false
    local found_conceal = false
    for _, extmark in ipairs(extmarks) do
      local details = extmark[4]
      local text = virt_text_to_string(details and details.virt_text)
      if details and details.virt_text_pos == 'inline' and text == '    ' then
        found_indent = true
      end
      if details and details.conceal == '󰉭' then
        found_conceal = true
      end
    end

    assert.is_true(found_indent)
    assert.is_true(found_conceal)
  end)

  it('renders a full-line background for headings', function()
    local namespace = vim.api.nvim_create_namespace('marklive_heading_background_test')
    local line = '### Level 3 Heading'
    local win_width = 30
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
    vim.api.nvim_set_hl(0, 'MarkliveTestHeadingDelimiter', {
      fg = '#00a79d',
      bg = '#173434',
      bold = true,
    })

    render.heading_marker({
      bufnr = 0,
      namespace = namespace,
      render_config = { line_background = true },
      hl_group = 'MarkliveTestHeadingDelimiter',
      icon = '󰉭',
      indent = 4,
      line = line,
      win_width = win_width,
      start_row = 0,
      start_col = 0,
      end_row = 0,
      end_col = 3,
    })

    local bg_group = 'MarkliveHeadingLineBg_MarkliveTestHeadingDelimiter'
    local bg_hl = vim.api.nvim_get_hl(0, { name = bg_group, link = false })
    local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
    local found_line_background = false
    local found_fill = false
    local found_indent_background = false
    local expected_fill = string.rep(' ', win_width - vim.fn.strdisplaywidth(line))

    for _, extmark in ipairs(extmarks) do
      local details = extmark[4]
      local text = virt_text_to_string(details and details.virt_text)
      if details and details.hl_group == bg_group and details.end_col == #line then
        found_line_background = true
      end
      if details and details.virt_text_pos == 'overlay' then
        found_fill = found_fill
          or (text == expected_fill and details.virt_text[1][2] == bg_group)
      end
      if details and details.virt_text_pos == 'inline' then
        found_indent_background = found_indent_background
          or (text == '    ' and details.virt_text[1][2] == bg_group)
      end
    end

    assert.are.equal(0x173434, bg_hl.bg)
    assert.is_true(found_line_background)
    assert.is_true(found_fill)
    assert.is_true(found_indent_background)
  end)
end)

describe('table markdown cell styling', function()
  local function render_table(lines)
    local namespace = vim.api.nvim_create_namespace('marklive_table_style_test')
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    render.table({
      bufnr = 0,
      namespace = namespace,
      config = {},
      start_row = 0,
      end_row = #lines,
    })

    return namespace
  end

  local function find_row_virt_text(namespace, row)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
    for _, extmark in ipairs(extmarks) do
      local details = extmark[4]
      if extmark[2] == row and details and details.virt_text then
        return details
      end
    end

    return nil
  end

  before_each(function()
    vim.cmd('enew!')
  end)

  it('renders inline code as a padded code chip without combining source highlights', function()
    local namespace = render_table({
      '| Header1 | Header2 | Header3 |',
      '| ------- | ------- | ------- |',
      '| Content1 | `Content5` | Content6 |',
    })
    local details = find_row_virt_text(namespace, 2)

    assert.is_not_nil(details)
    assert.are.equal('replace', details.hl_mode)

    local found_code = false
    for _, chunk in ipairs(details.virt_text) do
      if chunk[1] == ' Content5 ' and chunk[2] == 'markdownCode' then
        found_code = true
      end
      assert.is_false(chunk[1]:find('│', 1, true) ~= nil and chunk[2] == 'markdownCode')
    end

    assert.is_true(found_code)
  end)

  it('keeps strikethrough styling away from table borders', function()
    local namespace = render_table({
      '| Header1 | Header2 | Header3 |',
      '| ------- | ------- | ------- |',
      '| ~~Content4~~ | ~~Content5~~ | Content6 |',
    })
    local details = find_row_virt_text(namespace, 2)

    assert.is_not_nil(details)
    assert.are.equal('replace', details.hl_mode)

    local strike_text = {}
    for _, chunk in ipairs(details.virt_text) do
      if chunk[2] == 'markdownStrike' then
        table.insert(strike_text, chunk[1])
        assert.is_false(chunk[1]:find('│', 1, true) ~= nil)
      end
    end

    assert.are.same({ 'Content4', 'Content5' }, strike_text)
  end)
end)

describe('markdown italic rendering', function()
  before_each(function()
    vim.cmd('enew!')
  end)

  it('highlights only italic content for underscore and asterisk emphasis', function()
    local namespace = render_markdown({
      '_italic_',
      '*italic*',
      'prefix _italic_ suffix',
      'prefix *italic* suffix',
    })

    assert.are.same({
      { row = 0, col = 1, end_col = 7 },
      { row = 1, col = 1, end_col = 7 },
      { row = 2, col = 8, end_col = 14 },
      { row = 3, col = 8, end_col = 14 },
    }, find_italic_extmarks(namespace))
  end)

  it('does not highlight text that is not Markdown emphasis', function()
    local namespace = render_markdown({
      '`_not italic_`',
      '`*not italic*`',
      '```lua',
      '_not italic_',
      '*not italic*',
      '```',
      'foo_bar_baz',
    })

    assert.are.same({}, find_italic_extmarks(namespace))
  end)
end)
