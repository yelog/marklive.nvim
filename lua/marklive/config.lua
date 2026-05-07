local is_dark_bg = vim.o.background ~= 'light'
-- 对齐 GitHub Markdown（Primer）常用配色：
-- light: border #d1d9e0, muted bg #f6f8fa
-- dark:  border #3d444d, muted bg #151b23
local block_quote_border_fg = is_dark_bg and '#3d444d' or '#d1d9e0'
local block_quote_bg = is_dark_bg and '#151b23' or '#f6f8fa'
local heading_bg = is_dark_bg and {
  h1 = '#3a2428',
  h2 = '#3a3028',
  h3 = '#173434',
  h4 = '#29263a',
  h5 = '#242d3d',
  h6 = '#332b3b',
} or {
  h1 = '#fff0ed',
  h2 = '#fff4ea',
  h3 = '#e5f7f5',
  h4 = '#f1eff8',
  h5 = '#eef4fb',
  h6 = '#f7f0fa',
}

return {
  -- is enable
  enable = true,
  -- show mode
  -- 1. 'insert-line': default value, show origin content of current line when insert mode and cursor is on the line
  -- 2. 'normal-line': show origin content of current line when normal mode and cursor is on the line
  -- 3. 'insert-all': show origin content of all when insert mode
  -- show_mode = 'insert-line',
  show_mode = 'normal-line',
  filetype = { 'markdown' }, -- or {"*.md", "*.wiki"}
  highlight_config = {
    markdownBold = {
      matchadd = "\\v\\<b\\>.*\\<\\/b\\>",
      highlight = { bold = true, fg = "#ef9020" }
    },
    markdownItalic = {
      highlight = { italic = true, fg = "#d8e020" }
    },
    markdownStrike = {
      highlight = { fg = "#939393", strikethrough = true }
    },
    markdownLinkText = {
      highlight = { fg = '#5c92fa', underline = true }
    },
    markdownLinkTextDelimiter = {
      highlight = { fg = '#5c92fa', underline = true }
    },
    markdownCode = {
      -- matchadd 已移除：改为与其它强调语法一致，代码块内部不再单独高亮行内代码
      highlight = { fg = "#00c4b0", bg = "#1f262f" }
    },
    markdownBlockquote = {
      -- 对齐 GitHub/Notion 风格：弱化竖线 + 轻微底色
      highlight = { fg = block_quote_border_fg, bg = block_quote_bg }
    },
    markdownFootnote = {
      highlight = { fg = '#5c92fa' }
    },
    markdownH1 = {
      highlight = { fg = '#ff6f61', bg = heading_bg.h1, bold = true }
    },
    markdownH1Delimiter = {
      highlight = { fg = '#ff6f61', bg = heading_bg.h1, bold = true }
    },
    markdownH2 = {
      highlight = { fg = "#f7c59f", bg = heading_bg.h2, bold = true }
    },
    markdownH2Delimiter = {
      highlight = { fg = "#f7c59f", bg = heading_bg.h2, bold = true }
    },
    markdownH3 = {
      highlight = { fg = "#00a79d", bg = heading_bg.h3, bold = true }
    },
    markdownH3Delimiter = {
      highlight = { fg = "#00a79d", bg = heading_bg.h3, bold = true }
    },
    markdownH4 = {
      highlight = { fg = "#6b5b95", bg = heading_bg.h4, bold = true }
    },
    markdownH4Delimiter = {
      highlight = { fg = "#6b5b95", bg = heading_bg.h4, bold = true }
    },
    markdownH5 = {
      highlight = { fg = "#92a8d1", bg = heading_bg.h5, bold = true }
    },
    markdownH5Delimiter = {
      highlight = { fg = "#92a8d1", bg = heading_bg.h5, bold = true }
    },
    markdownH6 = {
      highlight = { fg = "#E8DAEF", bg = heading_bg.h6, bold = true }
    },
    markdownH6Delimiter = {
      highlight = { fg = "#E8DAEF", bg = heading_bg.h6, bold = true }
    },
    -- extend
    markliveMarkText = {
      matchadd = "\\v\\<mark\\>.*\\<\\/mark\\>",
      highlight = { bg = '#FFFF00', fg = '#000000' }
    },
    markliveTag = {
      -- Match a space followed by a hash symbol and any characters that are not a hash or space
      matchadd = "\\v\\s\\zs#[^# ]+",
      highlight = { fg = '#BB9AF7', bg = '#484360' }
    },
    markliveUser = {
      -- Match a space followed by an at symbol and any characters that are not an at or space
      matchadd = "\\v \\@[^@ ]+",
      highlight = { fg = '#FC7A07' }
    },
    markliveCalloutNote = {
      highlight = { fg = '#047AFF', bg = "#23283B" }
    },
    markliveCalloutError = {
      highlight = { fg = '#FB464C', bg = "#2E202A" }
    },
    markliveCalloutTip = {
      highlight = { fg = '#53DFDD', bg = "#242D3C" }
    },
    markliveCalloutWarning = {
      highlight = { fg = '#E9973F', bg = "#31292C" }
    }
  },
  render = {
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
      },
      after_highlight = { fg = "#939393", strikethrough = true }
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
      -- Using a separate rendering method;
      -- firstly because Tree-sitter parses lists inconsistently—the first item
      -- in an indented list has a width of 4, while the others have a width of 2;
      -- Secondly, to preserve spaces.;
      render = 'list'
    },
    list_marker_star = { -- List marker star
      icon = '',
      highlight = {
        fg = '#00C5DE'
      },
      render = 'list'
    },
    list_marker_plus = { -- List marker plus
      icon = '',
      highlight = {
        fg = '#9FF8BB'
      },
      render = 'list'
    },
    link = { -- Link
      icon = { '🔗' },
      regex = "[^!]%[[^%[%]]-%](%([^)]-%))",
      hl_group = 'markdownLinkText',
    },
    -- Can't write a regular expression
    link_first = {
      icon = { '🔗', '' },
      regex = "^%[[^%[%]]-%](%([^)]-%))",
      hl_group = 'markdownLinkText',
    },
    image = { -- Image
      icon = { '', '🎨' },
      regex = "(!)%[[^%[%]]-%](%(.-%))",
      hl_group = 'markdownLinkText',
    },
    pipe_table = {
      icon = '│',
      hl_group = 'tableBorder',
      render = 'table',
    },
    inline_code = { -- inline code
      icon = ' ',
      hl_group = "markdownCode",
      regex = '(`)[^`\n]+(`)',
    },
    italic = { -- Italic
      hl_group = "markdownItalic",
      -- Use lookbehind and lookahead to ensure _ is not surrounded by letters
      regex = "[^%a](_)[^_%s][^_]*(_)[^%a]",
    },
    bolder = { -- bolder
      icon = '',
      regex = "(%*%*)[^%*]+(%*%*)",
    },
    html_bolder = { -- bolder
      hl_group = 'markdownBold',
      icon = '',
      regex = "(<b>).-(</b>)",
    },
    strikethrough = { -- strikethrough
      regex = "(~~)[^~]+(~~)",
    },
    underline = { -- underline
      regex = "(<u>).-(</u>)",
    },
    mark = {
      regex = "(<mark>).-(</mark>)",
      hl_group = 'markliveMarkText',
    },
    thematic_break = { -- divider
      icon = '─',
      whole_line = true,
      hl_group = "markdownRule",
    },
    code_block = { -- Code block
      icon = "",
      query = { "(fenced_code_block) @code_block",
        "(indented_code_block) @code_block" },
      -- regex = "(```)([.\n]-)(```)",
      hl_fill = true,
      hl_group = 'MarkliveCodeblock',
      render = 'code_block',
      language_styles = {
        default = { icon = '', fg = '#89B4FA' },
        c = { icon = '', fg = '#A6E3A1' },
        cpp = { icon = '', fg = '#89B4FA' },
        css = { icon = '', fg = '#61AFEF' },
        docker = { icon = '', fg = '#7DD3FC' },
        go = { icon = '', fg = '#5DC9E2' },
        html = { icon = '', fg = '#FF8A65' },
        http = { icon = '󰖟', fg = '#56B6C2' },
        java = { icon = '', fg = '#F8BD76' },
        js = { icon = '', fg = '#F7DF1E' },
        json = { icon = '', fg = '#E5C07B' },
        lua = { icon = '', fg = '#7AA2F7' },
        md = { icon = '', fg = '#C0CAF5' },
        php = { icon = '', fg = '#CBA6F7' },
        py = { icon = '', fg = '#FFD43B' },
        react = { icon = '', fg = '#61DAFB' },
        ruby = { icon = '', fg = '#FF6B6B' },
        rust = { icon = '', fg = '#DEA584' },
        sh = { icon = '', fg = '#A6E3A1' },
        sql = { icon = '', fg = '#7DD3FC' },
        ts = { icon = '', fg = '#5EA0EF' },
        vim = { icon = '', fg = '#98C379' },
        yaml = { icon = '', fg = '#F7768E' },
      }
    },
    block_quote = { -- Block quote
      icon = "▎",
      render = "block_quote",
      hl_group = 'markdownBlockquote',
      callout = {
        note = {
          icon = '',
          hl_group = 'markliveCalloutNote',
        },
        error = {
          icon = '',
          hl_group = 'markliveCalloutError',
        },
        tip = {
          icon = '󰛨',
          hl_group = 'markliveCalloutTip',
        },
        warning = {
          icon = '',
          hl_group = 'markliveCalloutWarning',
        }
      }
    },
    atx_h1_marker = { -- Heading 1
      icon = "󰉫",
      hl_group = "markdownH1Delimiter",
      indent = 0,
      line_background = true,
      render = "heading_marker",
      -- hl_fill = true,
    },
    atx_h2_marker = { -- Heading 2
      icon = "󰉬",
      hl_group = "markdownH2Delimiter",
      indent = 2,
      line_background = true,
      render = "heading_marker"
    },
    atx_h3_marker = { -- Heading 3
      icon = "󰉭",
      hl_group = "markdownH3Delimiter",
      indent = 4,
      line_background = true,
      render = "heading_marker"
    },
    atx_h4_marker = { -- Heading 4
      icon = "󰉮",
      hl_group = "markdownH4Delimiter",
      indent = 6,
      line_background = true,
      render = "heading_marker"
    },
    atx_h5_marker = { -- Heading 5
      icon = "󰉯",
      hl_group = "markdownH5Delimiter",
      indent = 8,
      line_background = true,
      render = "heading_marker"
    },
    atx_h6_marker = { -- Heading 6
      icon = "󰉰",
      hl_group = "markdownH6Delimiter",
      indent = 10,
      line_background = true,
      render = "heading_marker"
    },
    tag = { -- Tag
      icon = "📌",
      hl_group = "markliveTag",
      regex = " (#)[^# ]+",
    },
    user = {
      icon = "👤",
      hl_group = "markliveUser",
      regex = " (@)[^@ ]+",
    }
  },
  render_delay = 10, -- ms
  action = {
    task = {
      -- 层级关系
      hierarchy = true
    },
    table = {
      enable = true,
    },
    list = {
      enable = true,
      unorder = { '-', '*', '+' }, -- Unordered list markers
    }
  }
}
