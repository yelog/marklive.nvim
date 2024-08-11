# 🚀 marklive.nvim

A Neovim plugin for rendering markdown files in terminal
<img width="2334" alt="marklive nvim" src="https://github.com/user-attachments/assets/51d2c2f6-f465-4f9c-85c7-018843b88c20">

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

The default configuration for **marklive.nvim** is shown in the link [config.lua](https://github.com/yelog/marklive.nvim)

If you don't want to use a Nerd Font, you can replace the icons with Unicode symbols.

# 📝 Plan


- Implement background style rendering for Markdown’s`Block Quote` 
- Implement style rendering for Markdown’s`Code Block`

# 🔑 License

**marklive.nvim** is licensed under the `Apache 2.0 license`


