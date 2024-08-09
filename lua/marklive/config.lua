return {
  -- is enable
  enable = true,
  -- show mode
  -- 1. 'insert-line': default value, show origin content of current line when insert mode and cursor is on the line
  -- 2. 'normal-line': show origin content of current line when normal mode and cursor is on the line
  -- 3. 'insert-all': show origin content of all when insert mode
  -- show_mode = 'insert-line',
  show_mode = 'normal-line',
  highlight_config = {
    MarkliveBold = {
      matchAdd = "\\v\\*\\*[a-zA-Z-_\\u4e00-\\u9fa5]+\\*\\*",
      highlight = { bold = true, fg = "#ef9020" }
    },
    MarkliveItalic = {
      matchAdd = "\\v[_\\*][^_\\*]+[_\\*]",
      highlight = { italic = true, fg = "#d8e020" }
    },
    MarkliveStrike = {
      matchAdd = "\\v[~_]{2}[^~_]+[~_]{2}",
      highlight = { fg = "#939393", strikethrough = true }
    },
    MarkliveLink = {
      matchAdd = "\\v(^|[^!])\\zs\\[[^\\]]+\\]\\([^\\)]+\\)",
      highlight = { fg = '#5c92fa', underline = true }
    },
    MarkliveImage = {
      matchAdd = "\\v\\!\\[[^\\[\\]]+\\]\\([^\\(\\)]+\\)",
      highlight = { fg = '#5c92fa', underline = true }
    },
    MarkliveMarkText = {
      matchAdd = "\\v\\<mark\\>.*\\<\\/mark\\>",
      highlight = { bg = '#FFFF00', fg = '#000000' }
    },
    MarkliveCode = {
      matchAdd = "\\v`[^`]+`",
      highlight = { fg = "#ffb454", bg = "#354251" }
    },
    MarkliveBlockQuote = {
      highlight = { fg = '#e6e1cf' }
    },
    MarkliveFootnote = {
      matchAdd = "\\v\\[\\^\\d\\]",
      highlight = { fg = '#5c92fa' }
    },
    MarkliveTag = {
      matchAdd = "\\v#\\S+",
      highlight = { fg = '#BB9AF7', bg = '#322E45' }
    },
    MarkliveH1 = {
      matchAdd = "\\v^\\s*#\\s+.*$",
      highlight = { fg = "#0082b4", bold = true }
    },
    MarkliveH2 = {
      matchAdd = "\\v^\\s*##\\s+.*$",
      highlight = { fg = "#ef9020", bold = true }
    },
    MarkliveH3 = {
      matchAdd = "\\v^\\s*###\\s+.*$",
      highlight = { fg = "#e990ab", bold = true }
    },
    MarkliveH4 = {
      matchAdd = "\\v^\\s*####\\s+.*$",
      highlight = { fg = "#96cbb3", bold = true }
    },
    MarkliveH5 = {
      matchAdd = "\\v^\\s*#####\\s+.*$",
      highlight = { fg = "#c196cb", bold = true }
    },
    MarkliveH6 = {
      matchAdd = "\\v^\\s*######\\s+.*$",
      highlight = { fg = "#96b7cb", bold = true }
    },
  },
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
      hl_group = 'MarkliveLink',
      icon_padding = { { 0, 1 } }
    },
    -- Can't write a regular expression
    link_first = {
      icon = { '', '' },
      regex = "^%[[^%[%]]-%](%([^)]-%))",
      hl_group = 'MarkliveLink',
      icon_padding = { { 0, 1 } }
    },
    image = { -- Image
      icon = { '', '' },
      regex = "(!)%[[^%[%]]-%](%(.-%))",
      hl_group = 'MarkliveImage',
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
      hl_group = "MarkliveFootnote",
    },
    markdownFootnote2 = {
      icon = '󰲢',
      regex = "(%[%^2%])",
      hl_group = "MarkliveFootnote",
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
    --   hl_group = 'MarkliveCodeblock'
    -- },
    block_quote_marker = { -- Block quote
      -- icon = "┃",
      icon = "▋",
      query = { "(block_quote_marker) @block_quote_marker",
        "(block_quote (paragraph (inline (block_continuation) @block_quote_marker)))",
        "(block_quote (paragraph (block_continuation) @block_quote_marker))",
        "(block_quote (block_continuation) @block_quote_marker)" },
      -- hl_fill = true,
      hl_group = 'MarkliveBlockQuote'
    },
    callout_note = {
      icon = { '', '' },
      regex = ">(%s%[!)NOTE(%])",
      hl_group = 'MarkliveBlockQuote',
    },
    callout_info = {
      icon = { '󰙎', '' },
      regex = ">(%s%[!)INFO(%])",
      hl_group = 'MarkliveBlockQuote',
    },
    atx_h1_marker = { -- Heading 1
      icon = "󰉫",
      hl_group = "MarkliveH1"
    },
    atx_h2_marker = { -- Heading 2
      icon = "󰉬",
      hl_group = "MarkliveH2"
    },
    atx_h3_marker = { -- Heading 3
      icon = "󰉭",
      hl_group = "MarkliveH3"
    },
    atx_h4_marker = { -- Heading 4
      icon = "󰉮",
      hl_group = "MarkliveH4"
    },
    atx_h5_marker = { -- Heading 5
      icon = "󰉯",
      hl_group = "MarkliveH5"
    },
    atx_h6_marker = { -- Heading 6
      icon = "󰉰",
      hl_group = "MarkliveH6"
    },
  },
}
