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

-- 切换任务状态
function M.toggle_task()
  if not is_markdown() then
    vim.notify("MarkliveToggleTask 只适用于 markdown 文件", vim.log.levels.WARN)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_get_current_line()
  local new_line = line

  if is_plain_list(line) then
    -- 普通 list，添加 [ ]
    new_line = line:gsub("^(%s*[-*+]%s+)", "%1[ ] ")
  elseif is_task_unchecked(line) or is_task_halfchecked(line) then
    -- 未完成任务或半选中任务，切换为已完成
    new_line = line:gsub("^(%s*[-*+]%s+)%[ ?%-%]", "%1[x]")
    new_line = new_line:gsub("^(%s*[-*+]%s+)%[ %]", "%1[x]")
    new_line = new_line:gsub("^(%s*[-*+]%s+)%[%-%]", "%1[x]")
  elseif is_task_checked(line) then
    -- 已完成任务，变回普通 list
    new_line = line:gsub("^(%s*[-*+]%s+)%[[xX]%]%s*", "%1")
  else
    vim.notify("当前行不是可切换的任务或列表", vim.log.levels.INFO)
    return
  end

  vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
end

-- 注册命令
vim.api.nvim_create_user_command("MarkliveToggleTask", function()
  require("marklive.action").toggle_task()
end, { desc = "切换 markdown 任务状态" })

return M
