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

local list_augroup_name = "MarkliveListAutocmd"

-- Get indent space count
local function get_indent(line)
  return #(line:match("^(%s*)") or "")
end

-- Find the column where list content begins (0-based when used with #)
local function get_list_content_col(line)
  local task_prefix = line:match("^(%s*[-*+]%s+%[[ xX%-]%]%s*)")
  if task_prefix then
    return #task_prefix
  end
  local plain_prefix = line:match("^(%s*[-*+]%s+)")
  if plain_prefix then
    return #plain_prefix
  end
  local ordered_prefix = line:match("^(%s*[%d]+%.%s+)")
  if ordered_prefix then
    return #ordered_prefix
  end
  return #line
end

local function is_supported_filetype(valid_filetypes, filetype)
  if type(valid_filetypes) == "string" then
    valid_filetypes = { valid_filetypes }
  end
  for _, ft in ipairs(valid_filetypes or {}) do
    if ft == filetype then
      return true
    end
  end
  return false
end

local function is_table_line(line)
  if not line then return false end
  if not line:match("^%s*|") then return false end
  local pipe_count = select(2, line:gsub("|", ""))
  return pipe_count >= 2
end

local function trim_cell(cell)
  return (cell and cell:match("^%s*(.-)%s*$")) or ""
end

local function split_table_row(line)
  local stripped = line:gsub("^%s*|", "", 1)
  stripped = stripped:gsub("|%s*$", "", 1)
  local cells = {}
  for cell in string.gmatch(stripped .. "|", "([^|]*)|") do
    table.insert(cells, cell)
  end
  if #cells == 0 then table.insert(cells, "") end
  return cells
end

local function is_separator_row(cells)
  if #cells == 0 then return false end
  for _, cell in ipairs(cells) do
    local trimmed = trim_cell(cell)
    if trimmed == "" or not trimmed:match("^:?-+:?$") then
      return false
    end
  end
  return true
end

local function get_alignments(cells, column_count)
  local res = {}
  for i = 1, column_count do
    local cell = cells[i]
    local trimmed = trim_cell(cell or "")
    local left_colon = trimmed:sub(1, 1) == ":"
    local right_colon = trimmed:sub(-1) == ":"
    local align = "left"
    if left_colon and right_colon then
      align = "center"
    elseif right_colon then
      align = "right"
    end
    res[i] = { align = align, left_colon = left_colon, right_colon = right_colon }
  end
  return res
end

local function compute_column_widths(rows, column_count)
  local widths = {}
  for col = 1, column_count do
    local max_width = 0
    for _, row in ipairs(rows) do
      local cell = trim_cell(row[col] or "")
      local w = vim.fn.strdisplaywidth(cell)
      if w > max_width then max_width = w end
    end
    widths[col] = max_width
  end
  return widths
end

local function build_separator_cell(width, align_info)
  local left_colon = align_info.left_colon
  local right_colon = align_info.right_colon
  local colon_count = (left_colon and 1 or 0) + (right_colon and 1 or 0)
  local hyphen_count = width - colon_count
  if hyphen_count < 1 then hyphen_count = 1 end
  local content = (left_colon and ":" or "") .. string.rep("-", hyphen_count) .. (right_colon and ":" or "")
  return " " .. content .. " "
end

local function build_content_cell(text, width, align)
  local content_width = vim.fn.strdisplaywidth(text)
  local extra = width - content_width
  if extra < 0 then extra = 0 end
  local left_pad = 1
  local right_pad = 1
  if align == "center" then
    local left_extra = math.floor(extra / 2)
    local right_extra = extra - left_extra
    left_pad = left_pad + left_extra
    right_pad = right_pad + right_extra
  elseif align == "right" then
    left_pad = left_pad + extra
  else
    right_pad = right_pad + extra
  end
  return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
end

local function format_table_lines(lines)
  local min_indent = nil
  for _, line in ipairs(lines) do
    local indent = get_indent(line)
    if not min_indent or indent < min_indent then
      min_indent = indent
    end
  end
  local indent_prefix = min_indent and string.rep(" ", min_indent) or ""
  local stripped_lines = {}
  for i, line in ipairs(lines) do
    stripped_lines[i] = line:sub((min_indent or 0) + 1)
  end

  local rows = {}
  local column_count = 0
  local separator_idx = nil
  for i, line in ipairs(stripped_lines) do
    local cells = split_table_row(line)
    rows[i] = cells
    column_count = math.max(column_count, #cells)
    if not separator_idx and is_separator_row(cells) then
      separator_idx = i
    end
  end
  if not separator_idx then
    return nil, "No table separator row found"
  end

  for _, cells in ipairs(rows) do
    for i = #cells + 1, column_count do
      cells[i] = ""
    end
  end

  local alignments = get_alignments(rows[separator_idx], column_count)
  local widths = compute_column_widths(rows, column_count)

  local formatted = {}
  for idx, cells in ipairs(rows) do
    local is_separator = idx == separator_idx
    local parts = { indent_prefix, "|" }
    for col = 1, column_count do
      if is_separator then
        table.insert(parts, build_separator_cell(widths[col], alignments[col]))
      else
        table.insert(parts, build_content_cell(trim_cell(cells[col]), widths[col], alignments[col].align))
      end
      table.insert(parts, "|")
    end
    formatted[idx] = table.concat(parts)
  end
  return formatted
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

function M.format_table()
  local config = get_config()
  if config.enable == false then return end

  local table_cfg = config.action and config.action.table
  if not (table_cfg and table_cfg.enable) then
    vim.notify("Table format is disabled by config", vim.log.levels.INFO)
    return
  end

  if not is_supported_filetype(config.filetype, vim.bo.filetype) then
    vim.notify("Table format works only for configured filetypes", vim.log.levels.WARN)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not is_table_line(line) then
    vim.notify("Current line is not a markdown table row", vim.log.levels.WARN)
    return
  end

  local total = vim.api.nvim_buf_line_count(0)
  local start_row = row
  while start_row > 1 do
    local prev_line = vim.api.nvim_buf_get_lines(0, start_row - 2, start_row - 1, false)[1]
    if prev_line and is_table_line(prev_line) then
      start_row = start_row - 1
    else
      break
    end
  end
  local end_row = row
  while end_row < total do
    local next_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
    if next_line and is_table_line(next_line) then
      end_row = end_row + 1
    else
      break
    end
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  local formatted, err = format_table_lines(lines)
  if not formatted then
    vim.notify(err or "Unable to format table", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, formatted)
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

-- 判断是否为有序列表（只支持数字）
local function is_ordered_list(line)
  local pat = "^%s*([%d]+%.)%s+"
  local m = line:match(pat)
  if m then
    return true, m
  end
  return false
end

-- 获取有序列表的序号和类型（只支持数字）
local function get_ordered_info(line)
  local num = line:match("^%s*([%d]+)%.%s+")
  if num then return tonumber(num), "1." end
  return nil, nil
end

-- 生成下一个有序列表序号（只支持数字）
local function next_ordered_number(prev, typ)
  return tostring(prev + 1) .. "."
end

-- 检查并修正有序列表序号连续性
local function fix_ordered_list(lines)
  -- 第一层有序列表按 treesitter 的 list 进行分组
  local ts_ok, ts = pcall(require, "vim.treesitter")
  if ts_ok then
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = ts.get_parser(bufnr, "markdown")
    if parser then
      local tree = parser:parse()[1]
      if tree then
        local root = tree:root()
        local query = vim.treesitter.query.parse("markdown", [[
          (list) @list
        ]])
        for id, node in query:iter_captures(root, bufnr, 0, -1) do
          if query.captures[id] == "list" then
            -- 收集该 list 下的所有有序列表项（只处理第一层）
            local indices = {}
            local indent = nil
            for child in node:iter_children() do
              if child:type() == "list_item" then
                local start_row, _, _, _ = child:range()
                local line = lines[start_row + 1]
                if line then
                  local ok, _ = is_ordered_list(line)
                  if ok then
                    table.insert(indices, start_row + 1)
                    if not indent then
                      indent = get_indent(line)
                    end
                  end
                end
              end
            end
            -- 修正该 list 下的有序列表序号
            if #indices > 0 and indent ~= nil then
              local num = 1
              for _, idx in ipairs(indices) do
                local pat = "^%s*([%d]+%.)%s+"
                lines[idx] = lines[idx]:gsub(pat, string.rep(" ", indent) .. tostring(num) .. ". ")
                num = num + 1
              end
            end
          end
        end
        return
      end
    end
  end
  -- fallback: 只支持数字有序列表，按缩进分组
  local indent_blocks = {}
  for i = 1, #lines do
    local ok, marker = is_ordered_list(lines[i])
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
        local pat = "^%s*([%d]+%.)%s+"
        lines[idx] = lines[idx]:gsub(pat, string.rep(" ", indent) .. tostring(num) .. ". ")
        num = num + 1
      end
    end
  end
end

-- 自动补全下一行列表
local function auto_new_list_line(opts)
  opts = opts or {}
  local suffix = opts.suffix or ""
  local config = get_config()
  local list_cfg = config.action and config.action.list
  if not (list_cfg and list_cfg.enable) then return end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
  if #lines == 0 then return end
  local line = lines[1]
  local unorder = list_cfg.unorder or { '-', '*', '+' }

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
    local final_line = suffix ~= "" and (new_line .. suffix) or new_line
    vim.api.nvim_buf_set_lines(0, row, row, false, { final_line })
    local target_col = suffix ~= "" and get_list_content_col(final_line) or #final_line
    vim.api.nvim_win_set_cursor(0, { row + 1, target_col })
    vim.cmd(suffix ~= "" and "startinsert" or "startinsert!")
    return true
  end

  -- 有序列表（只支持数字）
  local ok, marker = is_ordered_list(line)
  if ok then
    -- 先插入新行（临时 marker，后续统一修正）
    local indent = line:match("^(%s*)")
    local temp_marker = marker -- 先用当前 marker
    local new_line = indent .. temp_marker .. " "
    if suffix ~= "" then
      new_line = new_line .. suffix
    end
    vim.api.nvim_buf_set_lines(0, row, row, false, { new_line })

    -- 插入后修正同层级所有有序列表序号
    local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    fix_ordered_list(all_lines)
    -- 只更新有变化的行
    local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = 1, #all_lines do
      if orig_lines[i] ~= all_lines[i] then
        vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
      end
    end

    -- 重新获取新插入行内容
    local fixed_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    local target_col = suffix ~= "" and get_list_content_col(fixed_line) or #fixed_line
    vim.api.nvim_win_set_cursor(0, { row + 1, target_col })
    vim.cmd(suffix ~= "" and "startinsert" or "startinsert!")
    return true
  end
  return false
end

-- O 向上插入
local function auto_new_list_line_above()
  local config = get_config()
  local list_cfg = config.action and config.action.list
  if not (list_cfg and list_cfg.enable) then return false end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local cur_line = vim.api.nvim_get_current_line()
  if not cur_line or cur_line == "" then return false end
  local unorder = list_cfg.unorder or { '-', '*', '+' }

  -- 无序列表/任务
  local is_unorder, marker = is_unordered_list(cur_line, unorder)
  if is_unorder then
    local indent = cur_line:match("^(%s*)") or ""
    local new_line
    if is_task_line(cur_line) then
      new_line = indent .. marker .. " [ ] "
    else
      new_line = indent .. marker .. " "
    end
    -- 保证 new_line 至少有 marker + 一个空格
    if not new_line:match("^%s*[-*+]%s") then
      new_line = new_line:gsub("^%s*([-*+])", "%1 ")
    end
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { new_line })
    local marker_start, marker_end = new_line:find("^%s*[-*+]%s")
    local cursor_col = marker_end and (marker_end + 1) or (#new_line + 1)
    vim.api.nvim_win_set_cursor(0, { row, cursor_col })
    vim.cmd("startinsert!")
    return true
  end

  -- 有序列表（只支持数字）
  local ok, marker = is_ordered_list(cur_line)
  if ok then
    local indent = cur_line:match("^(%s*)") or ""
    local indent_len = #indent
    local cur_num, typ = get_ordered_info(cur_line)
    local new_marker = marker
    if cur_num and typ then
      local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local prev_same_indent_num = nil
      for i = row - 2, 0, -1 do
        local candidate = buflines[i + 1]
        if candidate then
          local candidate_indent = get_indent(candidate)
          if candidate_indent == indent_len then
            local candidate_ok = is_ordered_list(candidate)
            if candidate_ok then
              local prev_num = get_ordered_info(candidate)
              if prev_num then
                prev_same_indent_num = prev_num
                break
              end
            end
          elseif candidate_indent < indent_len then
            break
          end
        end
      end
      if prev_same_indent_num then
        new_marker = next_ordered_number(prev_same_indent_num, typ)
      else
        new_marker = tostring(cur_num) .. "."
      end
    end

    local new_line = indent .. new_marker .. " "
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { new_line })

    -- 修正所有同级有序列表的序号（插入后再修正）
    local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    fix_ordered_list(all_lines)
    -- 只更新有变化的行
    local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = 1, #all_lines do
      if orig_lines[i] ~= all_lines[i] then
        vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
      end
    end

    -- 重新获取新插入行内容
    local fixed_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local marker_start, marker_end = fixed_line:find("^%s*[%w%.]+%s")
    local cursor_col = marker_end and (marker_end + 1) or (#fixed_line + 1)
    vim.api.nvim_win_set_cursor(0, { row, cursor_col })
    vim.cmd("startinsert!")
    return true
  end
  return false
end

-- 列表缩进/反缩进
local function list_indent(direction)
  local config = get_config()
  local list_cfg = config.action and config.action.list
  local processed = false
  if not (list_cfg and list_cfg.enable) then return false end

  -- 只允许在 config.filetype 指定的文件类型中生效
  local filetype = vim.bo.filetype
  local valid_filetypes = config.filetype
  if type(valid_filetypes) == "string" then
    valid_filetypes = { valid_filetypes }
  end
  local matched = false
  for _, ft in ipairs(valid_filetypes or {}) do
    if ft == filetype then
      matched = true
      break
    end
  end
  if not matched then
    return false
  end

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
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  local unorder = list_cfg.unorder or { '-', '*', '+' }

  -- 记录光标原始列
  local orig_cursor = vim.api.nvim_win_get_cursor(0)
  local orig_col = orig_cursor[2]

  -- 先做缩进/反缩进
  local indent_delta = 0
  for i, line in ipairs(lines) do
    local idx = i + start_row - 1
    local indent = get_indent(line)
    -- 无序
    local is_unorder, marker = is_unordered_list(line, unorder)
    if is_unorder then
      local cur_idx = 1
      for j, m in ipairs(unorder) do
        if m == marker then
          cur_idx = j
          break
        end
      end
      if direction == "indent" then
        -- normal/visual 模式都切换为下一个无序列表类型
        cur_idx = (cur_idx) % #unorder + 1
        local content = line:gsub("^%s*[-*+]%s*", "")
        lines[i] = string.rep(" ", indent + 4) .. unorder[cur_idx] .. " " .. content
        processed = true
        if i == 1 then indent_delta = 4 end
      else
        -- 反缩进时切换为上一个无序列表类型
        cur_idx = (cur_idx - 2 + #unorder) % #unorder + 1
        local content = line:gsub("^%s*[-*+]%s*", "")
        lines[i] = (indent >= 4 and string.rep(" ", indent - 4) or "") .. unorder[cur_idx] .. " " .. content
        processed = true
        if i == 1 then indent_delta = (indent >= 4) and -4 or 0 end
      end
    else
      -- 有序（只支持数字）
      local ok, marker = is_ordered_list(line)
      if ok then
        if direction == "indent" then
          lines[i] = string.rep(" ", indent + 4) .. "1." .. line:gsub("^%s*[%d]+%.", "")
          processed = true
          if i == 1 then indent_delta = 4 end
        else
          lines[i] = (indent >= 4 and string.rep(" ", indent - 4) or "") .. "1." .. line:gsub("^%s*[%d]+%.", "")
          processed = true
          if i == 1 then indent_delta = (indent >= 4) and -4 or 0 end
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
  fix_ordered_list(all_lines)

  -- 只修改有变化的行
  local fixed_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i = 1, #all_lines do
    if fixed_lines[i] ~= all_lines[i] then
      vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
    end
  end

  -- 缩进后移动光标
  if indent_delta ~= 0 and mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    local new_col = math.max(0, orig_col + indent_delta)
    vim.api.nvim_win_set_cursor(0, { orig_cursor[1], new_col })
  end
  return processed
end

-- 暴露内部函数，便于需要时外部或命令调用
M._list_indent = list_indent

-- 自动命令和映射
local function setup_list_autocmd()
  pcall(vim.api.nvim_del_augroup_by_name, list_augroup_name)

  local config = get_config()
  local list_cfg = config.action and config.action.list
  if config.enable == false or not (list_cfg and list_cfg.enable) then
    return
  end

  -- InsertEnter时记录插入模式起始行
  local insert_start_row = nil
  local group = vim.api.nvim_create_augroup(list_augroup_name, { clear = true })
  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    group = group,
    callback = function(event)
      if vim.bo[event.buf].filetype ~= "markdown" then return end
      insert_start_row = vim.api.nvim_win_get_cursor(0)[1]
    end
  })
  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    group = group,
    callback = function(event)
      if vim.bo[event.buf].filetype ~= "markdown" then return end
      -- 仅当上一行为有序/无序/任务列表，且当前行为空时触发
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      if row < 2 then return end
      local prev_line = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
      local cur_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
      -- 只在当前行为空且处于插入模式下的 o/O 操作时触发
      if cur_line ~= "" then return end
      -- 如果是通过删除到行首导致的空行，不自动补全
      -- 检查光标是否在第0列（行首），且前一行不是列表
      -- 修正：只有在 col==0 且当前行为空时，才阻止自动补全（即只阻止“删到行首”触发，正常回车不影响）
      if col == 0 then return end
      local config = get_config()
      local list_cfg = config.action and config.action.list
      local unorder = list_cfg and (list_cfg.unorder or { '-', '*', '+' }) or { '-', '*', '+' }
      local is_unorder = is_unordered_list(prev_line, unorder)
      local is_order = is_ordered_list(prev_line)
      local is_task = is_task_line(prev_line)
      if is_unorder or is_order or is_task then
        -- 删除当前空行，调用自动补全
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})
        vim.api.nvim_win_set_cursor(0, { row - 1, #prev_line })
        vim.schedule(function()
          auto_new_list_line()
        end)
      end
    end
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    group = group,
    callback = function(event)
      local buf = event.buf
      if vim.bo[buf].filetype ~= "markdown" then return end
      -- o
      vim.keymap.set("n", "o", function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local cur_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
        -- 检查是否为“只有序列符号+空格”的新行
        local is_empty_ordered = cur_line and cur_line:match("^%s*%d+%.%s*$")
        local is_empty_unordered = cur_line and cur_line:match("^%s*[-*+]%s*$")
        if is_empty_ordered or is_empty_unordered then
          -- 删除当前行内容，光标移到行首并进入插入模式
          vim.api.nvim_buf_set_lines(0, row - 1, row, false, { "" })
          vim.api.nvim_win_set_cursor(0, { row, 0 })
          vim.cmd("startinsert!")
          -- 如果是有序列表，需要重新修正序号
          if is_empty_ordered then
            local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            fix_ordered_list(all_lines)
            local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            for i = 1, #all_lines do
              if orig_lines[i] ~= all_lines[i] then
                vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
              end
            end
          end
          return
        end
        if not auto_new_list_line() then
          -- 兼容普通回车，手动插入新行并进入插入模式
          vim.api.nvim_feedkeys("o", "n", false)
        end
      end, { buffer = buf, noremap = true, silent = true })
      -- O
      vim.keymap.set("n", "O", function()
        -- 只在当前行本身是列表/任务时才尝试智能补全上一行
        local cur_line = vim.api.nvim_get_current_line()
        local config = get_config()
        local list_cfg = config.action and config.action.list
        local unorder = list_cfg and (list_cfg.unorder or { '-', '*', '+' }) or { '-', '*', '+' }
        local is_unorder, _ = is_unordered_list(cur_line, unorder)
        local is_order = is_ordered_list(cur_line)
        local is_task = is_task_line(cur_line)
        if is_unorder or is_order or is_task then
          if not auto_new_list_line_above() then
            vim.api.nvim_feedkeys("O", "n", false)
          end
        else
          -- 当前行不是列表（例如位于列表块下方的空行），保持原生 O 行为
          vim.api.nvim_feedkeys("O", "n", false)
        end
      end, { buffer = buf, noremap = true, silent = true })
      -- 回车（insert模式）自动补全列表
      vim.keymap.set("i", "<CR>", function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local cur_line = vim.api.nvim_get_current_line()
        -- 检查是否为“只有序列符号+空格”的新行
        local is_empty_ordered = cur_line and cur_line:match("^%s*%d+%.%s*$")
        local is_empty_unordered = cur_line and cur_line:match("^%s*[-*+]%s*$")
        local is_empty_task = cur_line and cur_line:match("^%s*[-*+]%s+%[ %]%s*$")
        if is_empty_ordered or is_empty_unordered or is_empty_task then
          -- 判断当前缩进
          local indent = #(cur_line:match("^(%s*)") or "")
          if indent == 0 then
            -- 顶层，删除当前行内容，光标移到行首
            vim.api.nvim_set_current_line("")
            vim.api.nvim_win_set_cursor(0, { row, 0 })
            -- 如果是有序列表，需要重新修正序号
            if is_empty_ordered then
              local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              fix_ordered_list(all_lines)
              local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              for i = 1, #all_lines do
                if orig_lines[i] ~= all_lines[i] then
                  vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
                end
              end
            end
          else
            -- 子层级，减少缩进一级
            local new_line = cur_line:gsub("^%s+", function(s)
              if #s <= 4 then
                return ""
              else
                return string.rep(" ", #s - 4)
              end
            end)
            -- 如果是无序或任务空行，减少缩进后同步上一层级已有的无序列表 marker（保证层级前缀统一）
            if (is_empty_unordered or is_empty_task) then
              local new_indent = #(new_line:match("^(%s*)") or "")
              local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              local replacement_marker = nil
              -- 向上寻找同缩进级别的上一条无序/任务列表，沿用其 marker
              for i = row - 2, 0, -1 do
                local l = buflines[i + 1]
                if l then
                  local l_indent = #(l:match("^(%s*)") or "")
                  if l_indent == new_indent then
                    local m = l:match("^%s*([-*+])%s+")
                    if m then
                      replacement_marker = m
                      break
                    end
                  elseif l_indent < new_indent then
                    -- 再往上已越过父级
                    break
                  end
                end
              end
              if replacement_marker then
                local current_marker = new_line:match("^%s*([-*+])%s+")
                if current_marker and current_marker ~= replacement_marker then
                  new_line = new_line:gsub("^(%s*)[-*+]", "%1" .. replacement_marker, 1)
                end
              end
            end
            vim.api.nvim_set_current_line(new_line)
            -- 如果是有序列表空行的反缩进，需要重新修正父/子两层的序号
            if is_empty_ordered then
              local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              fix_ordered_list(all_lines)
              local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              for i = 1, #all_lines do
                if orig_lines[i] ~= all_lines[i] then
                  vim.api.nvim_buf_set_lines(0, i - 1, i, false, { all_lines[i] })
                end
              end
            end
            -- 光标移动到新行行尾
            vim.api.nvim_win_set_cursor(0, { row, #new_line })
          end
          return
        end
        -- 仅当当前行为有序/无序/任务列表时，才自动补全
        local config = get_config()
        local list_cfg = config.action and config.action.list
        local unorder = list_cfg and (list_cfg.unorder or { '-', '*', '+' }) or { '-', '*', '+' }
        local is_unorder = is_unordered_list(cur_line, unorder)
        local is_order = is_ordered_list(cur_line)
        local is_task = is_task_line(cur_line)
        if is_unorder or is_order or is_task then
          local suffix = ""
          local line_len = #cur_line
          if col < line_len then
            local content_start = get_list_content_col(cur_line)
            if col >= content_start then
              local left = cur_line:sub(1, col)
              suffix = cur_line:sub(col + 1)
              vim.api.nvim_set_current_line(left)
            end
          end
          -- 只自动补全，不再发送原始<CR>，避免多出一行
          auto_new_list_line({ suffix = suffix })
        else
          -- 普通回车
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end
      end, { buffer = buf, noremap = true, silent = true })
      -- visual 模式下 >/< 一下即可缩进/反缩进
      -- 支持 . 重复，使用 :normal! 执行命令并注册 repeat
      -- 非列表行（包括 # 标题等）在使用 >> / << 或 visual 模式下 > / < 时
      -- 之前 fallback 到 normal! >> / << 某些 markdown 配置下无效
      -- 改为手动计算并添加/删除 shiftwidth 空格，保证标题行也能缩进/反缩进
      local function fallback_shift(direction)
        local mode = vim.fn.mode()
        local shift = vim.bo.shiftwidth
        if shift == 0 then shift = vim.o.shiftwidth end
        if shift == 0 then shift = vim.o.tabstop end
        if shift == 0 then shift = 2 end  -- 保险兜底

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

        local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
        local indent_delta = 0
        for i, l in ipairs(lines) do
          if direction == "indent" then
            lines[i] = string.rep(" ", shift) .. l
            if i == 1 then indent_delta = shift end
          else
            -- 反缩进：最多移除 shift 个前导空格
            local cur_indent = #(l:match("^(%s*)") or "")
            local remove = math.min(cur_indent, shift)
            if remove > 0 then
              lines[i] = l:sub(remove + 1)
              if i == 1 then indent_delta = -remove end
            end
          end
        end
        vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, lines)

        -- 单行模式下调整光标
        if indent_delta ~= 0 and not (mode == "v" or mode == "V" or mode == "\22") then
          local cursor = vim.api.nvim_win_get_cursor(0)
          local new_col = math.max(0, cursor[2] + indent_delta)
            vim.api.nvim_win_set_cursor(0, { cursor[1], new_col })
        end
      end

      local repeatable_indent = function(direction)
        return function()
          local ok = list_indent(direction)
          if not ok then
            fallback_shift(direction)
            return
          end
          -- 仅在自定义列表缩进行为时设置 repeat
          vim.fn["repeat#set"](":lua require'marklive.action'.repeat_list_indent('" .. direction .. "')\r")
        end
      end

      M.repeat_list_indent = function(direction)
        local ok = list_indent(direction)
        if not ok then
          local m = vim.fn.mode()
            if m == "v" or m == "V" or m == "\22" then
              if direction == "indent" then
                vim.cmd("normal! >")
              else
                vim.cmd("normal! <")
              end
            else
              if direction == "indent" then
                vim.cmd("normal! >>")
              else
                vim.cmd("normal! <<")
              end
            end
          return
        end
        vim.fn["repeat#set"](":lua require'marklive.action'.repeat_list_indent('" .. direction .. "')\r")
      end

      vim.keymap.set("v", ">", repeatable_indent("indent"), { buffer = buf, noremap = true, silent = true })
      vim.keymap.set("v", "<", repeatable_indent("outdent"), { buffer = buf, noremap = true, silent = true })
      -- normal 模式下 >>/<< 也用自定义逻辑
      -- 加 nowait 解决在插入模式使用 <C-o> 后输入 >> / << 被当成文字插入的问题
      -- 去掉 nowait，确保 <C-o>> / <C-o><< 在插入模式下能够被识别为完整的多键映射（否则第一个 '>' 立即生效，无法组成 ">>"）
      vim.keymap.set("n", ">>", repeatable_indent("indent"), { buffer = buf, noremap = true, silent = true, desc = "Marklive list indent" })
      vim.keymap.set("n", "<<", repeatable_indent("outdent"), { buffer = buf, noremap = true, silent = true, desc = "Marklive list outdent" })

      -- 为插入模式下的 <C-o>> / <C-o><< 提供可靠映射，避免多键普通模式映射在 <C-o> 场景下失效
      pcall(vim.api.nvim_create_user_command, "MarkliveListIndent", function() list_indent("indent") end, {})
      pcall(vim.api.nvim_create_user_command, "MarkliveListOutdent", function() list_indent("outdent") end, {})
      -- 支持按 <C-o>>>（对称于 <C-o><<），避免多出一个 '>' 被插入
      vim.keymap.set("i", "<C-o>>>", "<C-o>:MarkliveListIndent<CR>", { buffer = buf, noremap = true, silent = true, desc = "Marklive list indent (insert <C-o>>>)" })
      -- 兼容只按一次 > 的情况
      vim.keymap.set("i", "<C-o>>", "<C-o>:MarkliveListIndent<CR>", { buffer = buf, noremap = true, silent = true, desc = "Marklive list indent (insert <C-o>>)" })
      vim.keymap.set("i", "<C-o><<", "<C-o>:MarkliveListOutdent<CR>", { buffer = buf, noremap = true, silent = true, desc = "Marklive list outdent (insert <C-o>)" })
    end
  })
end

M.setup_list_autocmd = setup_list_autocmd

-- 初始化
setup_list_autocmd()

return M
