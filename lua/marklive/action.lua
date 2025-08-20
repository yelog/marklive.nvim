local M = {}

-- Check if current buffer is a markdown file
local function is_markdown()
  return vim.bo.filetype == "markdown"
end

-- Check if a line is a plain list (- / * / + at start, not followed by [ ] or [x])
local function is_plain_list(line)
  return line:match("^%s*[-*+]%s+[^%[]") ~= nil
end

-- Check if a line is an unchecked task (- [ ])
local function is_task_unchecked(line)
  return line:match("^%s*[-*+]%s+%[ %]") ~= nil
end

-- Check if a line is a half-checked task (- [-] or * [-])
local function is_task_halfchecked(line)
  return line:match("^%s*[-*+]%s+%[%-%]") ~= nil
end

-- Check if a line is a checked task (- [x] or - [X])
local function is_task_checked(line)
  return line:match("^%s*[-*+]%s+%[[xX]%]") ~= nil
end

-- Get current config
local function get_config()
  local ok, mod = pcall(require, "marklive")
  if ok and mod and mod.config then
    return mod.config
  end
  return require("marklive.config")
end

-- Get indent space count
local function get_indent(line)
  return #(line:match("^(%s*)") or "")
end

-- Check if a line is a task line
local function is_task_line(line)
  return is_task_unchecked(line) or is_task_halfchecked(line) or is_task_checked(line)
end

-- Set the task state of a line
local function set_task_state(line, state)
  -- state: "unchecked", "checked", "halfchecked"
  if state == "checked" then
    line = line:gsub("^(%s*[-*+]%s+)%[ ?%-%]", "%1[x]")
    line = line:gsub("^(%s*[-*+]%s+)%[ %]", "%1[x]")
    line = line:gsub("^(%s*[-*+]%s+)%[%-%]", "%1[x]")
  elseif state == "unchecked" then
    line = line:gsub("^(%s*[-*+]%s+)%[[xX]%]", "%1[ ]")
    line = line:gsub("^(%s*[-*+]%s+)%[%-%]", "%1[ ]")
  elseif state == "halfchecked" then
    line = line:gsub("^(%s*[-*+]%s+)%[[xX]%]", "%1[-]")
    line = line:gsub("^(%s*[-*+]%s+)%[ %]", "%1[-]")
  end
  return line
end

-- Recursively set all children task states
local function set_children_state(lines, start_idx, parent_indent, state)
  local i = start_idx + 1
  while i <= #lines do
    local line = lines[i]
    local indent = get_indent(line)
    if indent <= parent_indent then
      break
    end
    if is_task_line(line) then
      lines[i] = set_task_state(line, state)
    end
    i = i + 1
  end
end

-- Recursively update parent task state to halfchecked/checked/unchecked
local function update_parent_state(lines, idx)
  local cur_idx = idx
  local cur_indent = get_indent(lines[cur_idx])
  while cur_idx > 1 do
    -- Find parent task upwards
    local parent_idx = nil
    local parent_indent = nil
    for i = cur_idx - 1, 1, -1 do
      local line = lines[i]
      local indent = get_indent(line)
      if indent < cur_indent and is_task_line(line) then
        parent_idx = i
        parent_indent = indent
        break
      end
    end
    if not parent_idx then
      break
    end

    -- Check all direct children task states (any indent greater than parent is a child)
    local child_states = { checked = 0, unchecked = 0, halfchecked = 0, total = 0 }
    local has_task_child = false
    for j = parent_idx + 1, #lines do
      local l = lines[j]
      local l_indent = get_indent(l)
      if l_indent <= parent_indent then break end
      if is_task_line(l) then
        has_task_child = true
        if is_task_checked(l) then
          child_states.checked = child_states.checked + 1
        elseif is_task_unchecked(l) then
          child_states.unchecked = child_states.unchecked + 1
        elseif is_task_halfchecked(l) then
          child_states.halfchecked = child_states.halfchecked + 1
        end
        child_states.total = child_states.total + 1
      elseif is_plain_list(l) then
        -- Plain list只计数，不计入total
        has_task_child = true
        -- child_states.unchecked = child_states.unchecked + 1
        -- child_states.total = child_states.total + 1
      end
    end
    -- 修正：只统计实际的任务子项（total>0），plain list不计入total
    if has_task_child and child_states.total > 0 then
      if child_states.checked == child_states.total then
        lines[parent_idx] = set_task_state(lines[parent_idx], "checked")
      elseif child_states.unchecked == child_states.total then
        lines[parent_idx] = set_task_state(lines[parent_idx], "unchecked")
      else
        lines[parent_idx] = set_task_state(lines[parent_idx], "halfchecked")
      end
    elseif not has_task_child then
      -- Parent task itself is a task, but has no children, keep original state
      -- If parent is checked and a child becomes unchecked, should become halfchecked
      -- No need to handle here, since no children
    end

    -- Continue upwards recursively
    cur_idx = parent_idx
    cur_indent = parent_indent
  end
end

-- Toggle task state (支持 normal 和 visual 模式)
function M.toggle_task()
  if not is_markdown() then
    vim.notify("MarkliveTaskToggle is only available for markdown files", vim.log.levels.WARN)
    return
  end

  local config = get_config()
  local hierarchy = config.action and config.action.task and config.action.task.hierarchy

  -- 检查是否为 visual 模式
  local mode = vim.fn.mode()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local changed_rows = {}

  local function process_line(row)
    local line = lines[row + 1]
    local new_line = line

    if is_plain_list(line) then
      -- Plain list, add [ ]
      new_line = line:gsub("^(%s*[-*+]%s+)", "%1[ ] ")
      lines[row + 1] = new_line
      table.insert(changed_rows, row + 1)
      return
    end

    if not hierarchy then
      -- 非层级模式
      if is_task_unchecked(line) or is_task_halfchecked(line) then
        new_line = set_task_state(line, "checked")
      elseif is_task_checked(line) then
        new_line = line:gsub("^(%s*[-*+]%s+)%[[xX]%]%s*", "%1")
      else
        return
      end
      lines[row + 1] = new_line
      table.insert(changed_rows, row + 1)
      return
    end

    -- 层级模式
    local cur_indent = get_indent(line)
    local changed = false
    if is_task_unchecked(line) or is_task_halfchecked(line) then
      lines[row + 1] = set_task_state(line, "checked")
      set_children_state(lines, row + 1, cur_indent, "checked")
      changed = true
    elseif is_task_checked(line) then
      lines[row + 1] = set_task_state(line, "unchecked")
      set_children_state(lines, row + 1, cur_indent, "unchecked")
      changed = true
    else
      return
    end
    if changed then
      table.insert(changed_rows, row + 1)
    end
  end

  if mode == "v" or mode == "V" or mode == "\22" then
    -- visual 模式
    local start_row, end_row
    if vim.fn.line("v") < vim.fn.line(".") then
      start_row = vim.fn.line("v") - 1
      end_row = vim.fn.line(".") - 1
    else
      start_row = vim.fn.line(".") - 1
      end_row = vim.fn.line("v") - 1
    end
    for row = start_row, end_row do
      process_line(row)
    end
    -- 层级模式下需要递归更新父任务
    if hierarchy then
      for _, row in ipairs(changed_rows) do
        update_parent_state(lines, row)
      end
      -- 一行一行设置，避免全量 set_lines 导致 extmark 被清除
      for i = 1, #lines do
        local orig_line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if orig_line ~= lines[i] then
          vim.api.nvim_buf_set_lines(0, i - 1, i, false, { lines[i] })
        end
      end
    else
      -- 非层级模式只更新选中行
      for _, row in ipairs(changed_rows) do
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { lines[row] })
      end
    end
    return
  else
    -- normal 模式
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    process_line(row)
    if #changed_rows == 0 then
      vim.notify("Current line is not a toggleable task or list", vim.log.levels.INFO)
      return
    end
    if hierarchy then
      update_parent_state(lines, row + 1)
      -- 一行一行设置，避免全量 set_lines 导致 extmark 被清除
      for i = 1, #lines do
        local orig_line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
        if orig_line ~= lines[i] then
          vim.api.nvim_buf_set_lines(0, i - 1, i, false, { lines[i] })
        end
      end
    else
      vim.api.nvim_buf_set_lines(0, row, row + 1, false, { lines[row + 1] })
    end
    return
  end
end

return M
