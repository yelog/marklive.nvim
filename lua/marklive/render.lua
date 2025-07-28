local utils = require('marklive.utils')
local render = {}

-- 判断某一行是否在代码块内
local function is_in_codeblock(bufnr, lnum)
  -- bufnr: buffer number
  -- lnum: 0-based line number
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, lnum + 1, false)
  local codeblock_count = 0
  for _, line in ipairs(lines) do
    if line:match("^%s*```") then
      codeblock_count = codeblock_count + 1
    end
  end
  return codeblock_count % 2 == 1
end

-- render.render_padding = function(namespace, icon_padding, padding_index, start_row, start_col, end_row, end_col, hl_group)
--   -- The final construction is in the format of {{0, 0}, {0, 0}}, if icon_padding is a single number, it is converted to {{0, 0}}
--   -- If it is two numbers {0, 0}, it is {{0,0}}, if it is already in the format of {{0,0}}, no processing is done
--   local final_icon_padding = {}
--   if type(icon_padding) == "number" then
--     final_icon_padding = { icon_padding, icon_padding }
--   elseif type(icon_padding) == "table" then
--     if #icon_padding == 0 or (type(icon_padding[1]) == 'number' and #icon_padding ~= 2) then
--       final_icon_padding = { 0, 0 }
--     elseif type(icon_padding[1]) == 'number' and type(icon_padding[2]) == 'number' then
--       final_icon_padding = { icon_padding[1], icon_padding[2] }
--     else
--       local matchIndex = false
--       for i, v in ipairs(icon_padding) do
--         if i == padding_index then
--           if type(v) == 'number' then
--             final_icon_padding = { v, v }
--           elseif type(v) == 'table' and #v == 2 and type(v[1]) == 'number' and type(v[2]) == 'number' then
--             final_icon_padding = { v[1], v[2] }
--           else
--             final_icon_padding = { 0, 0 }
--           end
--           -- break the loop
--           matchIndex = true
--           break
--         else
--         end
--       end
--       if not matchIndex then
--         final_icon_padding = { 0, 0 }
--       end
--     end
--   else
--     final_icon_padding = { 0, 0 }
--   end
--   local fill_content = ' '
--   if final_icon_padding[1] ~= 0 then
--     vim.api.nvim_buf_set_extmark(0, namespace, start_row, start_col, {
--       virt_text = { { fill_content:rep(final_icon_padding[1]), hl_group } },
--       virt_text_pos = "inline",
--       hl_mode = "combine",
--     })
--   end
--   if final_icon_padding[2] ~= 0 then
--     vim.api.nvim_buf_set_extmark(0, namespace, end_row, end_col, {
--       virt_text = { { fill_content:rep(final_icon_padding[2]), hl_group } },
--       virt_text_pos = "inline",
--       hl_mode = "combine",
--       conceal = '^'
--     })
--   end
-- end


render.init = function(namespace, config, query, regex_list)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

  -- If the file type is not markdown, return directly
  local filetype = vim.bo.filetype
  if filetype ~= "markdown" then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local width = vim.api.nvim_win_get_width(0)

  local ts = vim.treesitter
  -- get praser
  local parser = ts.get_parser(bufnr, filetype)
  -- get parser tree
  local tree = parser:parse()[1]
  -- get root node
  local root = tree:root()
  -- parse query
  local query_obj = ts.query.parse(filetype, query)

  -- Iterate over the query results
  for id, node in query_obj:iter_captures(root, bufnr, 0, -1) do
    local name = query_obj.captures[id]
    local icon = type(config.render[name].icon) == "table" and config.render[name].icon[1] or
        config.render[name].icon
    local hl_group = config.render[name].hl_group or name
    local start_row, start_col, end_row, end_col = node:range()
    -- get line content
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    local line_length = #line
    local icon_padding = config.render[name].icon_padding

    -- 检查是否在代码块内，如果是则跳过渲染
    if is_in_codeblock(bufnr, start_row) then
      goto continue_query
    end

    if type(config.render[name].render) == "function" then
      config.render[name].render({
        bufnr = bufnr,
        namespace = namespace,
        hl_group = hl_group,
        line = line,
        win_width = width,
        icon = icon,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col
      })
    elseif type(config.render[name].render) == 'string' and type(render[config.render[name].render]) ~= 'nil' then
      render[config.render[name].render]({
        bufnr = bufnr,
        namespace = namespace,
        hl_group = hl_group,
        line = line,
        win_width = width,
        icon = icon,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col
      })
    else
      if config.render[name].whole_line then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, 0, {
          virt_text = { { icon:rep(width), hl_group } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      else
        vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, {
          end_line = end_row,
          end_col = end_col,
          conceal = icon,
          hl_group = hl_group, -- use_name
          priority = 0,        -- To ignore conceal hl_group when focused
        })
        -- 通用 after_highlight 支持：如果配置了 after_highlight，则对匹配项后到行尾应用该高亮
        local after_hl = config.render[name].after_highlight
        if after_hl then
          local line_content = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
          local after_col = end_col
          local hl_group_to_use = after_hl
          if type(after_hl) == "table" then
            local group_name = "MarkliveAfterHighlight_" .. name
            vim.api.nvim_set_hl(0, group_name, after_hl)
            hl_group_to_use = group_name
          end
          if after_col < #line_content then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, after_col, {
              end_line = start_row,
              end_col = #line_content,
              hl_group = hl_group_to_use,
              priority = 1,
            })
          end
        end
      end
      local fill_content = ' '
      if config.render[name].hl_fill then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, line_length, {
          virt_text = { { fill_content:rep(width - line_length - 1), hl_group } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
    ::continue_query::
    -- Insert padding
    -- render.render_padding(namespace, icon_padding, 0, start_row, start_col, end_row, end_col, hl_group)
  end
  for name, regex in pairs(regex_list) do
    local icon = config.render[name].icon or '';
    local matches = utils.find_matches_with_groups(vim.api.nvim_buf_get_lines(0, 0, -1, false), regex)
    local icon_padding = config.render[name].icon_padding
    for _, match in ipairs(matches) do
      -- 检查是否在代码块内，如果是则跳过渲染
      if is_in_codeblock(bufnr, match.lnum) then
        goto continue_regex
      end
      if #match.groups == 0 then
        local hl_group = config.render[name].hl_group or name
        vim.api.nvim_buf_set_extmark(bufnr, namespace, match.lnum, match.start_col, {
          end_line = match.lnum,
          end_col = match.end_col,
          conceal = type(icon) == "table" and icon[1] or icon,
          hl_group = hl_group,
          priority = 0,
        })
        -- render.render_padding(namespace, icon_padding, 0, match.start_row, match.start_col, match.end_row, match.end_col,
        -- hl_group)
      else
        for i, group in ipairs(match.groups) do
          local hl_group = config.render[name].hl_group or name
          local conceal = type(icon) == "table" and icon[i] or icon
          vim.api.nvim_buf_set_extmark(bufnr, namespace, match.lnum, group.start_col, {
            end_line = match.lnum,
            end_col = group.end_col + 1,
            conceal = conceal,
            hl_group = hl_group,
            priority = 0,
          })
          -- render.render_padding(namespace, config.render[name].icon_padding, i, match.lnum, group.start_col, match.lnum,
          -- group.end_col + 1, hl_group)
        end
      end
      ::continue_regex::
    end
  end
end

render.list = function(rc)
  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.end_col - 2, {
    end_line = rc.end_row,
    end_col = rc.end_col - 1,
    conceal = rc.icon,
    hl_group = rc.hl_group, -- use_name
    priority = 0,           -- To ignore conceal hl_group when focused
  })
end

-- 仅使用 conceal 很难实现列的等宽, 考虑使用 virt_text 来实现, 但是要考虑到性能(支持光标所在行显示源码)
---@param rc table
render.table = function(rc)
  -- 定义高亮组
  local border_hl = "MarkliveTableBorder"
  local header_hl = "MarkliveTableHeader"

  -- 定义高亮（只需定义一次即可）
  vim.api.nvim_set_hl(0, border_hl, { fg = "#ef9020" })
  vim.api.nvim_set_hl(0, header_hl, { fg = "#ef9020", bold = true })

  -- border 字符定义
  local border = {
    '┌', '┬', '┐',
    '├', '┼', '┤',
    '└', '┴', '┘',
    '│', '─',
  }

  local bufnr = rc.bufnr
  local namespace = rc.namespace
  local start_row = rc.start_row
  local end_row = rc.end_row
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  -- 解析表格每行每列内容
  local table_cells = {}
  local column_max_width = {}

  for i, line in ipairs(lines) do
    local row = {}
    for cell in string.gmatch(line, "|([^|]*)") do
      local cell_text = vim.trim(cell)
      table.insert(row, cell_text)
    end
    -- 移除最后一个空列（如果存在且内容为空）
    if #row > 0 and row[#row] == "" then
      table.remove(row, #row)
    end
    table.insert(table_cells, row)
    for col, cell_text in ipairs(row) do
      local cell_len = vim.fn.strdisplaywidth(cell_text)
      column_max_width[col] = math.max(column_max_width[col] or 0, cell_len)
    end
  end

  local col_count = #column_max_width

  -- 构造边框行（横线）
  local function make_border_row(left, mid, right)
    local row = {}
    table.insert(row, { left, border_hl })
    for i = 1, col_count do
      table.insert(row, { string.rep(border[11], column_max_width[i] + 2), border_hl })
      if i < col_count then
        table.insert(row, { mid, border_hl })
      end
    end
    table.insert(row, { right, border_hl })
    return row
  end

  local top_border    = make_border_row(border[1], border[2], border[3])
  local middle_border = make_border_row(border[4], border[5], border[6])
  local bottom_border = make_border_row(border[7], border[8], border[9])

  -- 构造内容行
  local function make_content_row(row_cells, is_header)
    local row = {}
    table.insert(row, { border[10], border_hl })
    for i = 1, col_count do
      local cell = row_cells[i] or ""
      local pad = column_max_width[i] - vim.fn.strdisplaywidth(cell)
      if is_header then
        table.insert(row, { " " .. cell .. string.rep(" ", pad + 1), header_hl })
      else
        table.insert(row, { " " .. cell .. string.rep(" ", pad + 1) })
      end
      table.insert(row, { border[10], border_hl })
    end
    return row
  end

  -- 检查光标是否在表格范围内，如果在则不渲染表格
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  if cursor_row >= start_row and cursor_row < end_row then
    return
  end

  -- 渲染虚拟文本边框（不占用实际行）
  local win_width = vim.api.nvim_win_get_width(0)
  local virt_opts = {
    virt_text_pos = "overlay",
    hl_mode = "combine",
  }

  -- 顶部边框（渲染在表格内容之前的上一行，不占用内容行）
  vim.api.nvim_buf_set_extmark(bufnr, namespace, math.max(0, start_row - 1), 0, vim.tbl_extend("force", virt_opts, {
    virt_text = top_border,
  }))

  -- 内容行
  for i, row_cells in ipairs(table_cells) do
    local is_header = i == 1
    local content = make_content_row(row_cells, is_header)
    local line_idx = start_row + i - 1
    local orig_line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1] or ""
    local orig_width = vim.fn.strdisplaywidth(orig_line)
    -- 计算内容宽度
    local render_width = 0
    for _, seg in ipairs(content) do
      render_width = render_width + vim.fn.strdisplaywidth(seg[1])
    end
    local fill = ""
    if render_width < orig_width then
      fill = string.rep(" ", orig_width - render_width)
      table.insert(content, { fill })
    end

    -- 检查当前行是否为 markdown 表格分隔线（如 |---|---|），如果是则只渲染横线，不渲染内容
    local is_sep_line = orig_line:match("^%s*|[%s%-%:|]+|%s*$") and orig_line:find("%-")
    if is_sep_line then
      local render_width2 = 0
      for _, seg in ipairs(middle_border) do
        render_width2 = render_width2 + vim.fn.strdisplaywidth(seg[1])
      end
      local fill2 = ""
      if render_width2 < orig_width then
        fill2 = string.rep(" ", orig_width - render_width2)
      end
      local virt = vim.deepcopy(middle_border)
      table.insert(virt, { fill2 })
      vim.api.nvim_buf_set_extmark(bufnr, namespace, line_idx, 0, vim.tbl_extend("force", virt_opts, {
        virt_text = virt,
      }))
    else
      vim.api.nvim_buf_set_extmark(bufnr, namespace, line_idx, 0, vim.tbl_extend("force", virt_opts, {
        virt_text = content,
      }))
    end
  end

  -- 底部边框（渲染在表格内容之后的下一行，不占用内容行）
  local last_line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, false)[1] or ""
  local orig_width = vim.fn.strdisplaywidth(last_line)
  local render_width = 0
  for _, seg in ipairs(bottom_border) do
    render_width = render_width + vim.fn.strdisplaywidth(seg[1])
  end
  local fill = ""
  if render_width < orig_width then
    fill = string.rep(" ", orig_width - render_width)
    table.insert(bottom_border, { fill })
  end
  vim.api.nvim_buf_set_extmark(bufnr, namespace, end_row, 0, vim.tbl_extend("force", virt_opts, {
    virt_text = bottom_border,
  }))
end

-- 用于渲染 markdown 表格分隔行（如 |---|---|），用连线替换
render.table_delimiter_row = function(rc)
  -- 交由 render.table 统一渲染分隔线，这里不做任何处理
  return
end

render.table_normal_cell = function(rc)
  -- 只替换 | 改为 │
  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.start_col - 2, {
    end_line = rc.end_row,
    end_col = rc.start_col - 1,
    conceal = rc.icon,
    hl_group = rc.hl_group, -- use_name
    priority = 0,           -- To ignore conceal hl_group when focused
  })
  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.end_col, {
    end_line = rc.end_row,
    end_col = rc.end_col + 1,
    conceal = rc.icon,
    hl_group = rc.hl_group, -- use_name
    priority = 0,           -- To ignore conceal hl_group when focused
  })
end

-- 表格渲染自动切换（normal模式下，光标进入表格取消渲染，离开表格重新渲染）
-- 多表格渲染信息存储（改为 buffer-local）
local table_ranges_by_buf = {}

-- 包装原始 table 渲染函数，记录每个表格范围
local _orig_table = render.table
render.table = function(rc)
  local bufnr = rc.bufnr
  if not table_ranges_by_buf[bufnr] then
    table_ranges_by_buf[bufnr] = {}
  end
  table.insert(table_ranges_by_buf[bufnr], {
    start_row = rc.start_row,
    end_row = rc.end_row,
    bufnr = rc.bufnr,
    namespace = rc.namespace,
    config = rc.config,
  })
  _orig_table(rc)
end

-- 监听光标移动
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = vim.api.nvim_create_augroup("MarkliveTableCursor", { clear = true }),
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local table_ranges = table_ranges_by_buf[bufnr] or {}
    if #table_ranges == 0 then return end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_row = cursor[1] - 1
    local cleared = false
    for _, tbl in ipairs(table_ranges) do
      local in_table = cursor_row >= tbl.start_row and cursor_row < tbl.end_row
      if in_table then
        -- 只清除当前表格的渲染
        vim.api.nvim_buf_clear_namespace(tbl.bufnr, tbl.namespace, tbl.start_row - 1, tbl.end_row + 1)
        cleared = true
      end
    end
    if not cleared then
      -- 光标不在任何表格内，重新渲染所有表格
      if render.last_namespace and render.last_config and render.last_query and render.last_regex_list then
        require('marklive.render').init(render.last_namespace, render.last_config, render.last_query, render.last_regex_list)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
  group = vim.api.nvim_create_augroup("MarkliveTableBufEnter", { clear = true }),
  callback = function()
    if render.last_namespace and render.last_config and render.last_query and render.last_regex_list then
      require('marklive.render').init(render.last_namespace, render.last_config, render.last_query, render.last_regex_list)
    end
  end,
})

-- 包装 init，记录 query 和 regex_list
render.last_query = nil
render.last_regex_list = nil
render.last_namespace = nil
render.last_config = nil
local _orig_init = render.init
render.init = function(namespace, config, query, regex_list)
  render.last_query = query
  render.last_regex_list = regex_list
  render.last_namespace = namespace
  render.last_config = config
  -- 渲染前清空当前 buffer 的表格信息
  local bufnr = vim.api.nvim_get_current_buf()
  table_ranges_by_buf[bufnr] = {}
  _orig_init(namespace, config, query, regex_list)
end

return render
