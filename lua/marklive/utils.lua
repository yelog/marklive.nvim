local utils = {}

-- get the number of capture groups in the regular expression
utils.get_capture_group_count = function(pattern)
  local _, count = string.gsub(pattern, "%b()", "")
  return count
end


-- find matches with groups and positions
utils.find_matches_with_groups = function(bufnr, pattern)
  local matches = {}
  local capture_group_count = utils.get_capture_group_count(pattern)
  local lnum = 0

  for _, line in ipairs(bufnr) do
    lnum = lnum + 1
    local start_pos = 1
    while start_pos <= #line do
      local captures = { string.match(line, pattern, start_pos) }
      local start_col, end_col = string.find(line, pattern, start_pos)

      if #captures == 0 then
        break
      end

      local match = { lnum = lnum - 1, groups = {}, start_col = start_col - 1, end_col = end_col - 1 }
      local current_pos = start_pos

      for i = 1, capture_group_count do
        local s, e = string.find(line, captures[i], current_pos, true)
        if s and e then
          match.groups[i] = { text = captures[i], start_col = s - 1, end_col = e - 1 }
          current_pos = e + 1
        end
      end

      -- confirm the start position of the next match to avoid infinite loop
      start_pos = current_pos + 1

      table.insert(matches, match)
    end
  end

  return matches
end


-- generate query and regex
utils.generate_query_regex = function(render)
  local regex_list = {}
  local queries = {}

  for name, content in pairs(render) do
    if (content.regex ~= nil) then
      regex_list[name] = content.regex
    elseif content.query == nil then
      table.insert(queries, string.format(
        '(%s) @%s',
        name, name
      ));
    elseif type(content.query) == "string" then
      table.insert(queries, content.query)
    elseif type(content.query) == "table" then
      for _, query_item in ipairs(content.query) do
        table.insert(queries, query_item)
      end
    end
  end

  return {
    -- split by \n, merge queries
    query = table.concat(queries, "\n"),
    regex_list = regex_list
  }
end

-- utils.original_highlights = {}
-- utils.highlight_configs = {}
--
-- utils.setHighlight = function(highlight_config, filetype)
--   if highlight_config == nil or filetype == nil then
--     return
--   end
--
--   local augroup = vim.api.nvim_create_augroup("CustomHighlightGroup", { clear = true })
--
--   -- 保存原有的 highlight 配置
--   utils.original_highlights[filetype] = {}
--
--   for name, config in pairs(highlight_config) do
--     if config ~= nil and config.highlight ~= nil then
--       -- 获取当前 highlight 的配置
--       local original_config = vim.api.nvim_get_hl_id_by_name(name)
--       -- 保存原有的配置
--       utils.original_highlights[filetype][name] = original_config
--     end
--   end
--
--   -- 保存当前的 highlight 配置
--   utils.highlight_configs[filetype] = highlight_config
--
--   vim.api.nvim_create_autocmd("FileType", {
--     group = augroup,
--     pattern = filetype,
--     callback = function()
--       for name, config in pairs(highlight_config) do
--         if config ~= nil then
--           if config.highlight ~= nil then
--             vim.api.nvim_set_hl(0, name, config.highlight)
--           end
--           if config.matchadd ~= nil then
--             vim.fn.matchadd(name, config.matchadd)
--           end
--         end
--       end
--     end
--   })
-- end
--
-- utils.clearHighlight = function(highlight_config, filetype)
--   if filetype == nil or utils.highlight_configs[filetype] == nil then
--     return
--   end
--
--   local highlight_config = utils.highlight_configs[filetype]
--
--   for name, _ in pairs(highlight_config) do
--     -- 恢复原有的 highlight 配置
--     if utils.original_highlights[filetype][name] then
--       vim.api.nvim_set_hl(0, name, utils.original_highlights[filetype][name])
--     else
--       -- 如果没有原始配置，清除自定义 highlight
--       vim.api.nvim_set_hl(0, name, {})
--     end
--   end
--
--   -- 清除配置信息
--   utils.highlight_configs[filetype] = nil
--   utils.original_highlights[filetype] = nil
-- end

utils.original_highlights = {}
utils.highlight_configs = {}

local augroup = vim.api.nvim_create_augroup("MarkliveHighlightGroup", { clear = true })

utils.setHighlight = function(highlight_config, filetype)
  if highlight_config == nil or filetype == nil then
    return
  end


  -- 保存原有的 highlight 配置
  utils.original_highlights[filetype] = {}

  for name, config in pairs(highlight_config) do
    if config ~= nil and config.highlight ~= nil then
      -- 获取当前 highlight 的配置
      local original_config = vim.api.nvim_get_hl(0, { name = name, link = false, create = false })
      -- 保存原有的配置，如果原有配置为空，保存一个空表
      utils.original_highlights[filetype][name] = original_config or {}
    end
  end

  -- 保存当前的 highlight 配置
  utils.highlight_configs[filetype] = highlight_config

  print('callback')
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = filetype,
    callback = function()
      for name, config in pairs(highlight_config) do
        if config ~= nil then
          if config.highlight ~= nil then
            vim.api.nvim_set_hl(0, name, config.highlight)
          end
          if config.matchadd ~= nil then
            vim.fn.matchadd(name, config.matchadd)
          end
        end
      end
    end
  })
end


-- todo 待解决: 清除后, 再次设置就会失败的问题
utils.clearHighlight = function(filetype)
  if filetype == nil or utils.highlight_configs[filetype] == nil then
    return
  end

  local highlight_config = utils.highlight_configs[filetype]

  for name, _ in pairs(highlight_config) do
    -- 恢复原有的 highlight 配置
    local original_config = utils.original_highlights[filetype] and utils.original_highlights[filetype][name]

    if original_config then
      -- 确保配置是有效的 Lua 表
      local hl_config = {}
      for k, v in pairs(original_config) do
        if type(v) == 'number' then
          hl_config[k] = v
        end
      end
      vim.api.nvim_set_hl(0, name, hl_config)
    else
      -- 如果没有原始配置，清除自定义 highlight
      vim.api.nvim_set_hl(0, name, {})
    end
  end

  -- 清除配置信息
  utils.highlight_configs[filetype] = nil
  utils.original_highlights[filetype] = nil
end

return utils
