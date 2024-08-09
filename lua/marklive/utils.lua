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

utils.setHighlight = function(highlight_config, filetype)
  if highlight_config == nil or filetype == nil then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    -- filetype 是数组, 如 { "markdown"}
    pattern = filetype,
    callback = function()
      -- Iterating over objects
      for name, config in pairs(highlight_config) do
        if (config ~= nil) then
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

-- utils.clearHighlight = function(highlight_config, filetype)
--   if highlight_config == nil or filetype == nil then
--     return
--   end
--
--   vim.api.nvim_create_autocmd("FileType", {
--     -- filetype 是数组, 如 { "markdown"}
--     pattern = filetype,
--     callback = function()
--       -- Iterating over objects
--       for name, config in pairs(highlight_config) do
--         if (config ~= nil) then
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

return utils
