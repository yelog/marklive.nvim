# Italic Rendering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reliably render `_text_` and `*text*` as yellow italic Markdown emphasis without styling code.

**Architecture:** Replace the line-regex italic renderer with a Markdown Tree-sitter emphasis capture. A dedicated renderer will use the parsed emphasis range to conceal only the first and last delimiter bytes and add a `markdownItalic` highlight extmark to the interior range. Tree-sitter owns context detection, excluding code spans, fenced code blocks, escaped punctuation, and non-emphasis text.

**Tech Stack:** Lua, Neovim extmarks, Neovim Tree-sitter, vusted.

---

### Task 1: Add failing emphasis-rendering tests

**Files:**
- Modify: `test/plugin_spec.lua`
- Modify: `lua/marklive/render.lua` only after the tests fail

**Step 1: Write the failing test helpers**

Add a `render_markdown(lines)` helper that:

```lua
local namespace = vim.api.nvim_create_namespace('marklive_italic_test')
vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.filetype = 'markdown'
require('marklive').setup({ render_delay = 0 })
require('marklive').render()
vim.wait(50)
return namespace
```

Also add a helper that finds an extmark with `details.hl_group == 'markdownItalic'` and returns its row, column, and end column.

**Step 2: Write the failing cases**

Add one spec that asserts highlighting ranges contain only `italic` for each source line:

```lua
{ '_italic_', '*italic*', 'prefix _italic_ suffix', 'prefix *italic* suffix' }
```

Add one spec that asserts no `markdownItalic` extmark exists for:

```lua
{ '`_not italic_`', '`*not italic*`', '```lua', '_not italic_', '*not italic*', '```', 'foo_bar_baz' }
```

**Step 3: Run the tests to verify they fail**

Run: `vusted ./test`

Expected: the new assertions fail because the current renderer uses only delimiter capture groups and a restrictive underscore regex.

### Task 2: Render Tree-sitter emphasis nodes

**Files:**
- Modify: `lua/marklive/config.lua:197-201`
- Modify: `lua/marklive/render.lua:762-859`

**Step 1: Replace the italic regex configuration with a Tree-sitter capture**

Replace the `render.italic.regex` entry with a query that captures Markdown `emphasis` nodes as `@italic`. Keep `hl_group = 'markdownItalic'`; do not add a regex fallback that can style code text.

**Step 2: Add a focused italic renderer**

Implement `render.italic(rc)` in `lua/marklive/render.lua`. It must:

```lua
-- Emphasis nodes include their one-byte opening and closing delimiters.
vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.start_col, {
  end_line = rc.start_row,
  end_col = rc.start_col + 1,
  conceal = '',
  hl_group = rc.hl_group,
})
vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.start_col + 1, {
  end_line = rc.end_row,
  end_col = rc.end_col - 1,
  hl_group = rc.hl_group,
})
vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.end_row, rc.end_col - 1, {
  end_line = rc.end_row,
  end_col = rc.end_col,
  conceal = '',
  hl_group = rc.hl_group,
})
```

Use `render = 'italic'` in the italic configuration so the existing Tree-sitter dispatch invokes it. Preserve the existing code-block skip as an additional guard. If the installed parser exposes emphasis through the `markdown_inline` language rather than `markdown`, adapt the parser/query selection in the smallest compatible way and retain the test coverage.

**Step 3: Run the focused and complete test suites**

Run: `vusted ./test`

Expected: all existing tests and the new italic tests pass.

### Task 3: Validate style and formatting

**Files:**
- Modify only files changed in Tasks 1-2 if formatting requires it

**Step 1: Format code**

Run: `stylua lua/marklive/config.lua lua/marklive/render.lua test/plugin_spec.lua`

**Step 2: Run repository checks**

Run: `stylua --check .`

Expected: exits successfully.

Run: `vusted ./test`

Expected: exits successfully.

**Step 3: Review the diff**

Run: `git diff -- lua/marklive/config.lua lua/marklive/render.lua test/plugin_spec.lua`

Expected: italic matching is Tree-sitter-based; content, rather than only delimiters, receives `markdownItalic`; no unrelated changes appear.

**Step 4: Commit**

Only if explicitly requested, stage the implementation files and commit with:

```bash
git commit -m "fix: render markdown italics with treesitter"
```
