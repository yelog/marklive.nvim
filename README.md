# 🚀 marklive.nvim

A Neovim plugin for rendering markdown files in terminal
<img width="2334" alt="marklive nvim" src="https://github.com/user-attachments/assets/51d2c2f6-f465-4f9c-85c7-018843b88c20">

# ✨ Features

- 💡 Any element (treesitter, regex_group) can be replaced with icons
- 💪 Built-in `markdown elements` config, `markdown` files work out of the box
- 💞 Built-in commands `MarkliveEnable`, `MarkliveDisable`, `MarkliveToggle` to enable/disable/toggle the `marklive` feature
- ✅ Built-in command `MarkliveTaskToggle` to toggle markdown task state (supports cascading according to `action.task.hierarchy` config)
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
    lazy = true,
    ft = "markdown",
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

The default configuration for **marklive.nvim** is shown in the link [config.lua](https://github.com/yelog/marklive.nvim/blob/main/lua/marklive/config.lua)

## Task Toggle (`MarkliveTaskToggle`)

You can use the command `:MarkliveTaskToggle` to toggle the state of markdown tasks (checkboxes) under the cursor.

- **Cascading (hierarchy) is enabled by default**: toggling a parent task will also cascade the change to all its subtasks, and parent tasks will update their state based on their children.
- If you want to disable cascading, set `action.task.hierarchy = false` in your config. When disabled, only the current line's task state will be toggled.

Example config to disable cascading:
```lua
require('marklive').setup({
  action = {
    task = {
      hierarchy = false
    }
  }
})
```

### Keymap Example

You can bind a shortcut to toggle the task state, for example, using `<CR>` (Enter) in normal mode:
```lua
vim.keymap.set("n", "<CR>", "<cmd>MarkliveTaskToggle<cr>", { desc = "Toggle markdown task" })
```

If you don't want to use a Nerd Font, you can replace the icons with Unicode symbols.

## Table Format

`marklive` 提供 `table_format()` 用于格式化光标所在的管道表格，按照分隔行推断对齐方式：
- 每列宽度取所有行去除左右空格后的最大显示宽度，内容与边框符号至少留 1 个空格。
- 分隔行 `----`/`:---` 视为左对齐，`:---:` 居中，`---:` 右对齐；需要补齐时在冒号间添加 `-`，其他行用空格补齐。
- 默认开启，可通过 `action.table.enable = false` 关闭。

配置示例：
```lua
require('marklive').setup({
  action = {
    table = { enable = true },
  }
})
```

插件在全局表 `Marklive` 上暴露了方法，便于通过 `keys` 配置绑定快捷键（风格示例如下）：
```lua
-- 例如在 Lazy.nvim opts 中
keys = {
  { "<leader>mtf", function() Marklive.table_format() end, desc = "Format markdown table" },
}
```
> 需要其他自定义函数时，也可以将它们放在同一个全局表中统一管理，避免散落的全局函数。

# 📝 Plan


- Implement background style rendering for Markdown’s`Block Quote` 
- Implement style rendering for Markdown’s`Code Block`

# 🔑 License

**marklive.nvim** is licensed under the `Apache 2.0 license`
