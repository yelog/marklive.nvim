local utils = require('marklive.utils')
local render = {}

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
    -- local line_length = #line
    local icon_padding = config.render[name].icon_padding

    if type(config.render[name].render) == "function" then
      -- config.render[name].render({ bufnr, namespace, hl_group, line, start_row, start_col, end_row, end_col })
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
      end
      -- local fill_content = ' '
      -- if config.render[name].hl_fill then
      --   -- Insert space from the end of the current line to the end of the line
      --   vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, line_length, {
      --     virt_text = { { fill_content:rep(width - line_length), hl_group } },
      --     virt_text_pos = "overlay",
      --     hl_mode = "combine",
      --   })
      -- end
    end
    -- Insert padding
    -- render.render_padding(namespace, icon_padding, 0, start_row, start_col, end_row, end_col, hl_group)
  end
  for name, regex in pairs(regex_list) do
    local icon = config.render[name].icon or '';
    local matches = utils.find_matches_with_groups(vim.api.nvim_buf_get_lines(0, 0, -1, false), regex)
    local icon_padding = config.render[name].icon_padding
    for _, match in ipairs(matches) do
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
          -- print(conceal, match.groups)
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

render.table = function(rc)
  print(rc.start_row, rc.end_row, rc.start_col, rc.end_col)
  -- 处理所有出现的 | 改为 │, 所有的 -|- 改为 ┼, 所有的 -| 改为 ├, 所有的 |- 改为 ┤
  local line = vim.api.nvim_buf_get_lines(rc.bufnr, rc.start_row, rc.end_row, false)
  local icon = '│';
  for i, v in ipairs(line) do
    print(v)
    -- 都使用 conceal 来实现
    vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row + i, 0, {
      virt_text = { { icon:rep(rc.win_width), rc.hl_group } },
      virt_text_pos = "overlay",
      hl_mode = "combine",
    })
  end
end

render.table_delimiter_row = function(rc)
  -- 对行内容 rc.line 进行字符循环
  for i = rc.start_col, rc.end_col - 1 do
    vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, i, {
      end_line = rc.end_row,
      end_col = i + 1,
      conceal = i == 0 and '├' or i == rc.end_col - 1 and '┤' or rc.line.sub(rc.line, i + 1, i + 1) == '|' and '┼' or
          '─',
      hl_group = rc.hl_group, -- use_name
      priority = 0,           -- To ignore conceal hl_group when focused
    })
  end
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

return render
