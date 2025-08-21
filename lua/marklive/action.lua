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

-- ===========================
-- 列表自动补全与缩进/反缩进逻辑
-- ===========================

-- 判断是否为无序列表
local function is_unordered_list(line, unorder)
  for _, marker in ipairs(unorder) do
    local pat = "^%s*(" .. vim.pesc(marker) .. ")%s+"
    if line:match(pat) then
      return true, marker
    end
  end
  return false
end

-- 判断是否为有序列表
local function is_ordered_list(line, order)
  for _, marker in ipairs(order) do
    local pat = "^%s*([%dAaIi]+%.)%s+"
    local m = line:match(pat)
    if m then
      return true, m
    end
  end
  return false
end

-- 获取有序列表的序号和类型
local function get_ordered_info(line)
  local num, typ = line:match("^%s*([%d]+)([%.])%s+")
  if num then return tonumber(num), "1." end
  num = line:match("^%s*([a])%.%s+")
  if num then return string.byte(num) - string.byte("a") + 1, "a." end
  num = line:match("^%s*([A])%.%s+")
  if num then return string.byte(num) - string.byte("A") + 1, "A." end
  num = line:match("^%s*([ivxlcdm]+)%.%s+")
  if num then return num, "i." end
  num = line:match("^%s*([IVXLCDM]+)%.%s+")
  if num then return num, "I." end
  return nil, nil
end

-- 生成下一个有序列表序号
local function next_ordered_number(prev, typ)
  if typ == "1." then
    return tostring(prev + 1) .. "."
  elseif typ == "a." then
    return string.char(string.byte("a") + prev) .. "."
  elseif typ == "A." then
    return string.char(string.byte("A") + prev) .. "."
  elseif typ == "i." or typ == "I." then
    -- 罗马数字递增（简单实现，超出范围不处理）
    local roman = { "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x" }
    local idx = 0
    for i, v in ipairs(roman) do
      if v == prev:lower() then idx = i break end
    end
    if idx > 0 and idx < #roman then
      return (typ == "I." and roman[idx+1]:upper() or roman[idx+1]) .. "."
    end
  end
  return "1."
end

-- 检查并修正有序列表序号连续性
local function fix_ordered_list(lines, order)
  -- 兼容调用时 order 可能是行号而不是表
  if type(order) ~= "table" then
    order = { '1.', 'a.', 'A.', 'i.', 'I.' }
  end

  -- 使用 treesitter 获取所有 list 区域
  local ts_ok, ts = pcall(require, "vim.treesitter")
  if not ts_ok then
    -- fallback: 旧逻辑
    local indent_blocks = {}
    for i = 1, #lines do
      local ok, marker = is_ordered_list(lines[i], order)
      if ok then
        local cur_indent = get_indent(lines[i])
        indent_blocks[cur_indent] = indent_blocks[cur_indent] or {}
        table.insert(indent_blocks[cur_indent], i)
      end
    end
    for indent, indices in pairs(indent_blocks) do
      if #indices > 0 then
        local _, typ = get_ordered_info(lines[indices[1]])
        local num = 1
        for _, idx in ipairs(indices) do
          local pat = "^%s*([%dAaIi]+%.)%s+"
          lines[idx] = lines[idx]:gsub(pat, string.rep(" ", indent) .. (typ == "1." and (tostring(num)..".") or next_ordered_number(num-1, typ)) .. " ")
          num = num + 1
        end
      end
    end
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local parser = ts.get_parser(bufnr, "markdown")
  if not parser then return end
  local tree = parser:parse()[1]
  if not tree then return end
  local root = tree:root()

  -- 遍历所有 list 区域
  local query = vim.treesitter.query.parse("markdown", [[
    (list) @list
  ]])
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    if query.captures[id] == "list" then
      -- 对每个 list 区域，按缩进分组
      local indent_blocks = {}
      for child in node:iter_children() do
        if child:type() == "list_item" then
          local start_row, _, _, _ = child:range()
          local line = lines[start_row+1]
          if line then
            local ok, marker = is_ordered_list(line, order)
            if ok then
              local cur_indent = get_indent(line)
              indent_blocks[cur_indent] = indent_blocks[cur_indent] or {}
              table.insert(indent_blocks[cur_indent], start_row+1)
            end
          end
        end
      end
      -- 对每个缩进层级的有序列表块，顺序编号
      for indent, indices in pairs(indent_blocks) do
        if #indices > 0 then
          local _, typ = get_ordered_info(lines[indices[1]])
          local num = 1
          for _, idx in ipairs(indices) do
            local pat = "^%s*([%dAaIi]+%.)%s+"
            lines[idx] = lines[idx]:gsub(pat, string.rep(" ", indent) .. (typ == "1." and (tostring(num)..".") or next_ordered_number(num-1, typ)) .. " ")
            num = num + 1
          end
        end
      end
    end
  end
end

-- 自动补全下一行列表
local function auto_new_list_line()
  local config = get_config()
  local list_cfg = config.action and config.action.list
  if not (list_cfg and list_cfg.enable) then return end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, row-1, row, false)
  if #lines == 0 then return end
  local line = lines[1]
  local unorder = list_cfg.unorder or { '-', '*', '+' }
  local order = list_cfg.order or { '1.', 'a.', 'A.', 'i.', 'I.' }

  -- 无序列表/任务
  local is_unorder, marker = is_unordered_list(line, unorder)
  if is_unorder then
    local indent = line:match("^(%s*)")
    local new_line
    -- 如果是任务列表（- [ ]），只生成 - [ ] 
    if is_task_line(line) then
      new_line = indent .. marker .. " [ ] "
    else
      new_line = indent .. marker .. " "
    end
    -- 保证 new_line 至少有 marker + 一个空格
    if not new_line:match("^%s*[-*+]%s") then
      new_line = new_line:gsub("^%s*([-*+])", "%1 ")
    end
    vim.api.nvim_buf_set_lines(0, row, row, false, { new_line })
    -- 将光标定位到 -/marker+空格 后
    local marker_start, marker_end = new_line:find("^%s*[-*+]%s")
    local cursor_col = marker_end and (marker_end + 1) or (#new_line + 1)
    vim.api.nvim_win_set_cursor(0, { row+1, cursor_col })
    vim.cmd("startinsert!")
    return true
  end

  -- 有序列表
  local ok, marker = is_ordered_list(line, order)
  if ok then
    -- 先插入新行（临时 marker，后续统一修正）
    local indent = line:match("^(%s*)")
    local temp_marker = marker -- 先用当前 marker
    local new_line = indent .. temp_marker .. " "
    vim.api.nvim_buf_set_lines(0, row, row, false, { new_line })

    -- 插入后修正同层级所有有序列表序号
    local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    fix_ordered_list(all_lines, order)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, all_lines)

    -- 重新获取新插入行内容
    local fixed_line = vim.api.nvim_buf_get_lines(0, row, row+1, false)[1]
    local marker_start, marker_end = fixed_line:find("^%s*[%w%.]+%s")
    local cursor_col = marker_end and (marker_end + 1) or (#fixed_line + 1)
    vim.api.nvim_win_set_cursor(0, { row+1, cursor_col })
    vim.cmd("startinsert!")
    return true
  end
  return false
end

-- O 向上插入
local function auto_new_list_line_above()
  local config = get_config()
  local list_cfg = config.action and config.action.list
  if not (list_cfg and list_cfg.enable) then return end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if row == 1 then return end
  local lines = vim.api.nvim_buf_get_lines(0, row-2, row-1, false)
  if #lines == 0 then return end
  local line = lines[1]
  local unorder = list_cfg.unorder or { '-', '*', '+' }
  local order = list_cfg.order or { '1.', 'a.', 'A.', 'i.', 'I.' }

  -- 无序列表/任务
  local is_unorder, marker = is_unordered_list(line, unorder)
  if is_unorder then
    local task = line:match("^%s*[-*+]%s+%[.?.?%]")
    local indent = line:match("^(%s*)")
    local new_line
    if task then
      new_line = indent .. marker .. " " .. task .. " "
    else
      new_line = indent .. marker .. " "
    end
    -- 保证 new_line 至少有 marker + 一个空格
    if not new_line:match("^%s*[-*+]%s") then
      new_line = new_line:gsub("^%s*([-*+])", "%1 ")
    end
    vim.api.nvim_buf_set_lines(0, row-1, row-1, false, { new_line })
    local marker_start, marker_end = new_line:find("^%s*[-*+]%s")
    local cursor_col = marker_end and (marker_end + 1) or (#new_line + 1)
    vim.api.nvim_win_set_cursor(0, { row, cursor_col })
    vim.cmd("startinsert!")
    return true
  end

  -- 有序列表
  local ok, marker = is_ordered_list(line, order)
  if ok then
    -- 先插入新行
    local prev_num, typ = get_ordered_info(line)
    if prev_num and typ then
      local indent = line:match("^(%s*)")
      local new_marker = next_ordered_number(prev_num, typ)
      local new_line = indent .. new_marker .. " "
      vim.api.nvim_buf_set_lines(0, row-1, row-1, false, { new_line })
      -- 修正所有同级有序列表的序号（插入后再修正）
      local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      fix_ordered_list(all_lines, row-1, order)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, all_lines)
      -- 重新获取新插入行内容
      local fixed_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
      local marker_start, marker_end = fixed_line:find("^%s*[%w%.]+%s")
      local cursor_col = marker_end and (marker_end + 1) or (#fixed_line + 1)
      vim.api.nvim_win_set_cursor(0, { row, cursor_col })
      vim.cmd("startinsert!")
      return true
    end
  end
  return false
end

-- 列表缩进/反缩进
local function list_indent(direction)
  local config = get_config()
  local list_cfg = config.action and config.action.list
  if not (list_cfg and list_cfg.enable) then return end

  local mode = vim.fn.mode()
  local start_row, end_row
  if mode == "v" or mode == "V" or mode == "\22" then
    if vim.fn.line("v") < vim.fn.line(".") then
      start_row = vim.fn.line("v") - 1
      end_row = vim.fn.line(".") - 1
    else
      start_row = vim.fn.line(".") - 1
      end_row = vim.fn.line("v") - 1
    end
  else
    start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    end_row = start_row
  end

  local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row+1, false)
  local unorder = list_cfg.unorder or { '-', '*', '+' }
  local order = list_cfg.order or { '1.', 'a.', 'A.', 'i.', 'I.' }

  -- 先做缩进/反缩进
  for i, line in ipairs(lines) do
    local idx = i + start_row - 1
    local indent = get_indent(line)
    -- 无序
    local is_unorder, marker = is_unordered_list(line, unorder)
    if is_unorder then
      local cur_idx = 1
      for j, m in ipairs(unorder) do
        if m == marker then cur_idx = j break end
      end
      if direction == "indent" then
        -- normal/visual 模式都切换为下一个无序列表类型
        cur_idx = (cur_idx) % #unorder + 1
        local content = line:gsub("^%s*[-*+]%s*", "")
        lines[i] = string.rep(" ", indent+4) .. unorder[cur_idx] .. " " .. content
      else
        -- 反缩进时切换为上一个无序列表类型
        cur_idx = (cur_idx - 2 + #unorder) % #unorder + 1
        local content = line:gsub("^%s*[-*+]%s*", "")
        lines[i] = (indent >= 4 and string.rep(" ", indent-4) or "") .. unorder[cur_idx] .. " " .. content
      end
    else
      -- 有序
      local ok, marker = is_ordered_list(line, order)
      if ok then
        local prev_num, typ = get_ordered_info(line)
        if prev_num and typ then
          if direction == "indent" then
            -- 缩进时切换序号类型
            local next_typ
            if typ == "1." then
              next_typ = "a."
            elseif typ == "a." then
              next_typ = "A."
            elseif typ == "A." then
              next_typ = "i."
            elseif typ == "i." then
              next_typ = "I."
            else
              next_typ = "a."
            end
            lines[i] = string.rep(" ", indent+4) .. next_typ .. line:gsub("^%s*[%dAaIi]+%.", "")
          else
            -- 反缩进时恢复为数字序号
            lines[i] = (indent >= 4 and string.rep(" ", indent-4) or "") .. "1." .. line:gsub("^%s*[%dAaIi]+%.", "")
          end
        end
      end
    end
  end

  -- 应用缩进/反缩进后的行，只修改有变化的行
  for i = 1, #lines do
    local global_idx = start_row + i
    if all_lines[global_idx] ~= lines[i] then
      vim.api.nvim_buf_set_lines(0, global_idx - 1, global_idx, false, { lines[i] })
      all_lines[global_idx] = lines[i]
    end
  end

  -- 缩进/反缩进后，重新修正所有有序列表的序号
  fix_ordered_list(all_lines, order)

  -- 只修改有变化的行
  local fixed_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = 1, #all_lines do
    if fixed_lines[i] ~= all_lines[i] then
      vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
    end
  end
end

-- 自动命令和映射
local function setup_list_autocmd()
  -- InsertEnter时记录插入模式起始行
  local insert_start_row = nil
  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    callback = function()
      insert_start_row = vim.api.nvim_win_get_cursor(0)[1]
    end
  })
  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    callback = function()
      -- 仅当上一行为有序/无序/任务列表，且当前行为空时触发
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      if row < 2 then return end
      local prev_line = vim.api.nvim_buf_get_lines(0, row-2, row-1, false)[1]
      local cur_line = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
      if cur_line ~= "" then return end
      local config = get_config()
      local list_cfg = config.action and config.action.list
      local unorder = list_cfg and (list_cfg.unorder or { '-', '*', '+' }) or { '-', '*', '+' }
      local order = list_cfg and (list_cfg.order or { '1.', 'a.', 'A.', 'i.', 'I.' }) or { '1.', 'a.', 'A.', 'i.', 'I.' }
      local is_unorder = is_unordered_list(prev_line, unorder)
      local is_order = is_ordered_list(prev_line, order)
      local is_task = is_task_line(prev_line)
      if is_unorder or is_order or is_task then
        -- 删除当前空行，调用自动补全
        vim.api.nvim_buf_set_lines(0, row-1, row, false, {})
        vim.api.nvim_win_set_cursor(0, { row-1, #prev_line })
        vim.schedule(function()
          auto_new_list_line()
        end)
      end
    end
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
      -- o
      vim.keymap.set("n", "o", function()
        if not auto_new_list_line() then
          return vim.api.nvim_feedkeys("o", "n", false)
        end
      end, { buffer = true, noremap = true, silent = true })
      -- O
      vim.keymap.set("n", "O", function()
        if not auto_new_list_line_above() then
          return vim.api.nvim_feedkeys("O", "n", false)
        end
      end, { buffer = true, noremap = true, silent = true })
      -- visual 模式下 >/< 一下即可缩进/反缩进
      vim.keymap.set("v", ">", function()
        list_indent("indent")
      end, { buffer = true, noremap = true, silent = true })
      vim.keymap.set("v", "<", function()
        list_indent("outdent")
      end, { buffer = true, noremap = true, silent = true })
      -- normal 模式下 >>/<< 也用自定义逻辑
      vim.keymap.set("n", ">>", function()
        list_indent("indent")
      end, { buffer = true, noremap = true, silent = true })
      vim.keymap.set("n", "<<", function()
        list_indent("outdent")
      end, { buffer = true, noremap = true, silent = true })
    end
  })
end

-- 初始化
setup_list_autocmd()

return M
