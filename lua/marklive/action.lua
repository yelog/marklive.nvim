local M = {}

-- 判断当前 buffer 是否为 markdown 文件
local function is_markdown()
  return vim.bo.filetype == "markdown"
end

-- 检查一行是否为普通 list（- / * / + 开头，后面不是 [ ] 或 [x]）
local function is_plain_list(line)
  return line:match("^%s*[-*+]%s+[^%[]") ~= nil
end

-- 检查一行是否为未完成任务（- [ ]）
local function is_task_unchecked(line)
  return line:match("^%s*[-*+]%s+%[ %]") ~= nil
end

-- 检查一行是否为半选中任务（- [-] 或 * [-]）
local function is_task_halfchecked(line)
  return line:match("^%s*[-*+]%s+%[%-%]") ~= nil
end

-- 检查一行是否为已完成任务（- [x] 或 - [X]）
local function is_task_checked(line)
  return line:match("^%s*[-*+]%s+%[[xX]%]") ~= nil
end

-- 获取当前配置
local function get_config()
  local ok, mod = pcall(require, "marklive")
  if ok and mod and mod.config then
    return mod.config
  end
  return require("marklive.config")
end

-- 获取缩进空格数
local function get_indent(line)
  return #(line:match("^(%s*)") or "")
end

-- 判断是否为任务行
local function is_task_line(line)
  return is_task_unchecked(line) or is_task_halfchecked(line) or is_task_checked(line)
end

-- 设置一行的任务状态
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

-- 递归设置所有子任务状态
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

-- 递归向上设置父任务半选中/全选/未选
local function update_parent_state(lines, idx)
  local cur_idx = idx
  local cur_indent = get_indent(lines[cur_idx])
  while cur_idx > 1 do
    -- 向上查找父任务
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

    -- 检查父任务的所有直接子任务状态（只要缩进大于父任务即可视为子任务）
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
        -- 普通列表也算作未完成
        has_task_child = true
        child_states.unchecked = child_states.unchecked + 1
        child_states.total = child_states.total + 1
      end
    end
    if has_task_child and child_states.total > 0 then
      if child_states.checked == child_states.total then
        lines[parent_idx] = set_task_state(lines[parent_idx], "checked")
      elseif child_states.unchecked == child_states.total then
        lines[parent_idx] = set_task_state(lines[parent_idx], "unchecked")
      else
        lines[parent_idx] = set_task_state(lines[parent_idx], "halfchecked")
      end
    elseif not has_task_child then
      -- 父任务本身是 task，但没有任何子任务，保持原状态
      -- 但如果父任务是 checked，且有子任务变为未完成，则应变为 halfchecked
      -- 这里无需处理，因无子任务
    end

    -- 继续向上递归
    cur_idx = parent_idx
    cur_indent = parent_indent
  end
end

-- 切换任务状态
function M.toggle_task()
  if not is_markdown() then
    vim.notify("MarkliveTaskToggle 只适用于 markdown 文件", vim.log.levels.WARN)
    return
  end

  local config = get_config()
  local hierarchy = config.action and config.action.task and config.action.task.hierarchy

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local line = lines[row + 1]
  local new_line = line

  if is_plain_list(line) then
    -- 普通 list，添加 [ ]
    new_line = line:gsub("^(%s*[-*+]%s+)", "%1[ ] ")
    lines[row + 1] = new_line
    -- 这里不直接 return，而是继续向下走，保证父任务能被递归更新
    -- changed = true 以便后续 update_parent_state
    local config = get_config()
    local hierarchy = config.action and config.action.task and config.action.task.hierarchy
    if hierarchy then
      update_parent_state(lines, row + 1)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      return
    else
      vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
      return
    end
  end

  if not hierarchy then
    -- 非层级模式，原有逻辑
    if is_task_unchecked(line) or is_task_halfchecked(line) then
      new_line = set_task_state(line, "checked")
    elseif is_task_checked(line) then
      new_line = line:gsub("^(%s*[-*+]%s+)%[[xX]%]%s*", "%1")
    else
      vim.notify("当前行不是可切换的任务或列表", vim.log.levels.INFO)
      return
    end
    vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
    return
  end

  -- 层级模式
  local cur_indent = get_indent(line)
  local changed = false
  if is_task_unchecked(line) or is_task_halfchecked(line) then
    -- 选中当前任务和所有子任务
    lines[row + 1] = set_task_state(line, "checked")
    set_children_state(lines, row + 1, cur_indent, "checked")
    changed = true
  elseif is_task_checked(line) then
    -- 取消选中当前任务和所有子任务
    lines[row + 1] = set_task_state(line, "unchecked")
    set_children_state(lines, row + 1, cur_indent, "unchecked")
    changed = true
  else
    vim.notify("当前行不是可切换的任务或列表", vim.log.levels.INFO)
    return
  end

  -- 写回所有变更行
  if changed then
    -- 先递归向上更新父任务状态（无论是批量操作还是单个子任务变更都能生效）
    update_parent_state(lines, row + 1)
    -- 最后统一写入 buffer
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
end

return M
