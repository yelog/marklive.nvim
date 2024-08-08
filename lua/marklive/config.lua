return {
  -- is enable
  enable = true,
  -- show mode
  -- 1. 'insert-line': default value, show origin content of current line when insert mode and cursor is on the line
  -- 2. 'normal-line': show origin content of current line when normal mode and cursor is on the line
  -- 3. 'insert-all': show origin content of all when insert mode
  -- show_mode = 'insert-line',
  show_mode = 'normal-line',
  preview = {
    task_list_marker_unchecked = { -- Task list marker unchecked
      icon = "",
      highlight = {
        fg = "#706357",
      }
    },
    task_list_marker_checked = { -- Task list marker checked
      icon = '󰄲',
      highlight = {
        fg = "#009f4d",
      }
    },
    task_list_marker_indeterminate = { -- Task list marker indeterminate
      icon = '󰡖',
      highlight = {
        fg = '#E9AD5B',
      },
      regex = '(%[%-%])',
    },
    list_marker_minus = { -- List marker minus
      icon = '',
      highlight = {
        fg = '#E9AD5B'
      },
      icon_padding = { 0, 1 }
    },
    list_marker_star = { -- List marker star
      icon = '',
      highlight = {
        fg = '#00C5DE'
      },
      icon_padding = { 0, 1 }
    },
    list_marker_plus = { -- List marker plus
      icon = '',
      highlight = {
        fg = '#9FF8BB'
      },
      icon_padding = { 0, 1 }
    },
    link = { -- Link
      icon = { '' },
      regex = "[^!]%[[^%[%]]-%](%([^)]-%))",
      hl_group = 'ye_link',
      icon_padding = { { 0, 1 } }
    },
    -- Can't write a regular expression
    link_first = {
      icon = { '', '' },
      regex = "^%[[^%[%]]-%](%([^)]-%))",
      hl_group = 'ye_link',
      icon_padding = { { 0, 1 } }
    },
    image = { -- Image
      icon = { '', '' },
      regex = "(!)%[[^%[%]]-%](%(.-%))",
      hl_group = 'ye_link',
      icon_padding = { { 0, 1 } }
    },
    tableLine = { -- Table line
      -- icon = '┃',
      icon = '│',
      regex = "[^|]+(%|)",
      hl_group = 'tableSeparator'
    },
    -- tableRow = {
    --   icon = '─',
    --   width = '',
    --   -- query = { "(pipe_table_delimiter_row (pipe_table_delimiter_cell) @tableRow)" },
    --   regex = '%-',
    --   hl_group = 'tableBorder'
    -- },
    inline_code = { -- inline code
      icon = ' ',
      hl_group = "markdownCode",
      regex = '(`)[^`\n]+(`)',
    },
    italic = { -- Italic
      regex = "([*_])[^*`~]-([*_])",
    },
    bolder = { -- bolder
      icon = '',
      regex = "(%*%*)[^%*]+(%*%*)",
    },
    strikethrough = { -- strikethrough
      regex = "(~~)[^~]+(~~)",
    },
    underline = { -- underline
      regex = "(<u>).-(</u>)",
    },
    mark = {
      regex = "(<mark>).-(</mark>)",
    },
    markdownFootnote1 = {
      icon = '󰲠',
      regex = "(%[%^1%])",
      hl_group = "markdownFootnote",
    },
    markdownFootnote2 = {
      icon = '󰲢',
      regex = "(%[%^2%])",
      hl_group = "markdownFootnote",
    },
    thematic_break = { -- divider
      icon = '─',
      whole_line = true,
      hl_group = "markdownRule",
    },
    -- code_block = { -- Code block
    --   icon = "",
    --   query = { "(fenced_code_block) @code_block",
    --     "(indented_code_block) @code_block" },
    --   -- regex = "(```)([.\n]-)(```)",
    --   hl_fill = true,
    --   hl_group = 'ye_codeblock'
    -- },
    block_quote_marker = { -- Block quote
      -- icon = "┃",
      icon = "▋",
      query = { "(block_quote_marker) @block_quote_marker",
        "(block_quote (paragraph (inline (block_continuation) @block_quote_marker)))",
        "(block_quote (paragraph (block_continuation) @block_quote_marker))",
        "(block_quote (block_continuation) @block_quote_marker)" },
      -- hl_fill = true,
      -- hl_group = 'ye_quote'
    },
    callout_note = {
      icon = { '', '' },
      regex = ">(%s%[!)NOTE(%])",
      hl_group = 'ye_quote',
    },
    callout_info = {
      icon = { '󰙎', '' },
      regex = ">(%s%[!)INFO(%])",
      hl_group = 'ye_quote',
    },
    atx_h1_marker = { -- Heading 1
      icon = "󰉫",
      hl_group = "markdownH1Delimiter"
    },
    atx_h2_marker = { -- Heading 2
      icon = "󰉬",
      hl_group = "markdownH2Delimiter"
    },
    atx_h3_marker = { -- Heading 3
      icon = "󰉭",
      hl_group = "markdownH3Delimiter"
    },
    atx_h4_marker = { -- Heading 4
      icon = "󰉮",
      hl_group = "markdownH4Delimiter"
    },
    atx_h5_marker = { -- Heading 5
      icon = "󰉯",
      hl_group = "markdownH5Delimiter"
    },
    atx_h6_marker = { -- Heading 6
      icon = "󰉰",
      hl_group = "markdownH6Delimiter"
    },
  },
}
