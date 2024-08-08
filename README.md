# 🚀 marklive.nvim

A Neovim plugin for rendering markdown files in terminal

# ✨ Features

- 💡 Any element (treesitter, regex_group) can be replaced with icons
- 💪 Built-in `markdown elements` config, `markdown` files work out of the box
- 💞 Built-in commands `MarkliveEnable`, `MarkliveDisable`, `MarkliveToggle` to enable/disable/toggle the `marklive` feature
- 🛴 Supports automatically disabling the `marklive` feature on the current line for easy editing
- 🔎 Highly configurable, allowing custom icons for each markdown element, and even custom displays for `html` files


# ⚡️ Requirements

- Neovim >= 0.5.0
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): Used for parsing files
- [Nerd Fonts](https://www.nerdfonts.co/): **(optional)** Used for displaying icons

# 📦 Installation

Using `lazy.nvim`

```lua
{
    "yelog/marklive.nvim",
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {}
}
```

Using `packer.nvim`

```lua
use {
  'yelog/marklive.nvim',
  requires = { 'nvim-treesitter/nvim-treesitter' },
}
```

Using `dein`

```lua
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('yelog/marklive.nvim')
```

Usingn `vim-plug`

```lua
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'yelog/marklive.nvim'
```

# ⚙️ Configuration

The default configuration for **marklive.nvim** is shown in the link [config.lua](https://github.com/yelog/marklive.nvim)

```lua
{
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
    link = {
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
    image = {
      icon = { '', '' },
      regex = "(!)%[[^%[%]]-%](%(.-%))",
      hl_group = 'ye_link',
      icon_padding = { { 0, 1 } }
    },
    tableLine = {
      -- icon = '┃',
      icon = '│',
      regex = "[^|]+(%|)",
      hl_group = 'tableSeparator'
    },
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
    thematic_break = {
      icon = '─',
      whole_line = true,
      hl_group = "markdownRule",
    },
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
```
If you don't want to use a Nerd Font, you can replace the icons with Unicode symbols.


# 📝 License

**marklive.nvim** is licensed under the `Apache 2.0 license`


