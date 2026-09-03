local utils = require('marklive.utils')
local render = {}
local has_virt_text_repeat_linebreak = vim.fn.has('nvim-0.10') == 1
local table_highlights_initialized = false
local table_layout_cache_by_buf = {}
local table_ranges_by_buf = {}

local function ensure_showbreak_padding(width)
  if width <= 0 or not vim.wo.wrap then
    return false
  end

  local showbreak = vim.wo.showbreak or ''
  local showbreak_width = vim.fn.strdisplaywidth(showbreak)
  if showbreak_width < width then
    -- 为软折行预留前缀占位，避免 overlay 续行覆盖正文首字符
    vim.wo.showbreak = showbreak .. string.rep(' ', width - showbreak_width)
    showbreak_width = vim.fn.strdisplaywidth(vim.wo.showbreak)
  end

  return showbreak_width >= width
end

local function set_block_quote_marker(bufnr, namespace, lnum, gt_end, line, icon, hl_group,
                                      repeat_on_wrap)
  local marker_col = gt_end - 1
  local marker_end_col = gt_end
  if line:sub(gt_end + 1, gt_end + 1) == ' ' then
    marker_end_col = gt_end + 1
  end

  -- 将 `> ` 收敛为单个竖线，避免正文与左边框之间出现额外空白
  vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, marker_col, {
    end_line = lnum,
    end_col = marker_end_col,
    conceal = icon,
    hl_group = hl_group,
    priority = 0,
  })

  if repeat_on_wrap and has_virt_text_repeat_linebreak then
    if ensure_showbreak_padding(vim.fn.strdisplaywidth(icon)) then
      local ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, lnum, marker_col, {
        virt_text = { { icon, hl_group } },
        virt_text_pos = 'overlay',
        virt_text_repeat_linebreak = true,
        hl_mode = 'combine',
        priority = 0,
      })
      if ok then
        return
      end
    end
  end
end

local function is_separator_row(cells)
  if #cells == 0 then return false end
  for _, cell in ipairs(cells) do
    local trimmed = vim.trim(cell)
    if trimmed == "" or not trimmed:match("^:?-+:?$") then
      return false
    end
  end
  return true
end

local function detect_alignments(table_cells, col_count)
  local alignments = {}
  for _, row in ipairs(table_cells) do
    if is_separator_row(row) then
      for i = 1, col_count do
        local cell = vim.trim(row[i] or "")
        local left_colon = cell:sub(1, 1) == ":"
        local right_colon = cell:sub(-1) == ":"
        local align = "left"
        if left_colon and right_colon then
          align = "center"
        elseif right_colon then
          align = "right"
        end
        alignments[i] = align
      end
      break
    end
  end
  return alignments
end

local function is_pipe_table_line(line)
  if not line then return false end
  if not line:match("^%s*|") then return false end
  local pipe_count = select(2, line:gsub("|", ""))
  return pipe_count >= 2
end

local function get_table_layout(bufnr, start_row, end_row)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cache = table_layout_cache_by_buf[bufnr]
  if not cache or cache.changedtick ~= changedtick then
    cache = { changedtick = changedtick, ranges = {} }
    table_layout_cache_by_buf[bufnr] = cache
  end

  local key = start_row .. ':' .. end_row
  if cache.ranges[key] then
    return cache.ranges[key]
  end

  local table_cells = {}
  local column_max_width = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  for _, line in ipairs(lines) do
    local row = {}
    for cell in string.gmatch(line, '|([^|]*)') do
      local cell_text = vim.trim(cell)
      table.insert(row, cell_text)
    end
    if #row > 0 and row[#row] == '' then
      table.remove(row, #row)
    end
    table.insert(table_cells, row)
    for col, cell_text in ipairs(row) do
      local cell_len = vim.fn.strdisplaywidth(cell_text)
      column_max_width[col] = math.max(column_max_width[col] or 0, cell_len)
    end
  end

  local layout = {
    table_cells = table_cells,
    column_max_width = column_max_width,
    col_count = #column_max_width,
    alignments = detect_alignments(table_cells, #column_max_width),
  }
  cache.ranges[key] = layout
  return layout
end

local codeblock_language_aliases = {
  bash = 'sh',
  cplusplus = 'cpp',
  ['c++'] = 'cpp',
  dockerfile = 'docker',
  fish = 'sh',
  javascript = 'js',
  javascriptreact = 'react',
  jsx = 'react',
  markdown = 'md',
  node = 'js',
  nodejs = 'js',
  python = 'py',
  python3 = 'py',
  shell = 'sh',
  terminal = 'sh',
  typescript = 'ts',
  typescriptreact = 'react',
  tsx = 'react',
  vimscript = 'vim',
  yml = 'yaml',
  zsh = 'sh',
}

local default_codeblock_language_style = { icon = '', fg = '#89B4FA' }

local function normalize_codeblock_language(lang)
  if not lang or lang == '' then
    return ''
  end

  return tostring(lang):lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function extract_codeblock_language(first_line)
  local lang = first_line:match('^%s*```+%s*{%s*%.([%w_+.-]+)')
    or first_line:match('^%s*~~~+%s*{%s*%.([%w_+.-]+)')
    or first_line:match('^%s*```+%s*([%w_+.-]+)')
    or first_line:match('^%s*~~~+%s*([%w_+.-]+)')

  return normalize_codeblock_language(lang)
end

local function get_codeblock_language_style(styles, lang)
  local canonical_lang = codeblock_language_aliases[lang] or lang
  return (styles and (styles[lang] or styles[canonical_lang] or styles.default))
    or default_codeblock_language_style
end

local function codeblock_language_hl_group(lang)
  local suffix = lang:gsub('[^%w_]', '_')
  if suffix == '' then
    suffix = 'default'
  end

  return 'MarkliveCodeblockLang_' .. suffix
end

local heading_bg_cache = {}

local function normalize_hex_color(color)
  if type(color) == 'number' then
    return string.format('#%06x', color)
  end

  if type(color) ~= 'string' then
    return nil
  end

  if color:sub(1, 1) ~= '#' then
    color = '#' .. color
  end

  if color:match('^#%x%x%x%x%x%x$') then
    return color
  end

  return nil
end

local function blend_hex_color(fg, bg, alpha)
  local fg_hex = fg:gsub('#', '')
  local bg_hex = bg:gsub('#', '')
  local result = {}

  for i = 1, 3 do
    local start_idx = (i - 1) * 2 + 1
    local fg_channel = tonumber(fg_hex:sub(start_idx, start_idx + 1), 16)
    local bg_channel = tonumber(bg_hex:sub(start_idx, start_idx + 1), 16)
    local channel = math.floor(fg_channel * alpha + bg_channel * (1 - alpha) + 0.5)
    table.insert(result, string.format('%02x', channel))
  end

  return '#' .. table.concat(result, '')
end

local function get_normal_bg()
  local normal_hl = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  local normal_bg = normalize_hex_color(normal_hl and normal_hl.bg)
  if normal_bg then
    return normal_bg
  end

  return vim.o.background == 'light' and '#ffffff' or '#1f1f28'
end

local function heading_line_bg_group(hl_group)
  if not hl_group then
    return nil
  end

  local hl_def = vim.api.nvim_get_hl(0, { name = hl_group, link = false })
  local bg = normalize_hex_color(hl_def and hl_def.bg)
  if not bg then
    local fg = normalize_hex_color(hl_def and hl_def.fg)
    if not fg then
      return nil
    end

    local alpha = vim.o.background == 'light' and 0.12 or 0.18
    bg = blend_hex_color(fg, get_normal_bg(), alpha)
  end

  local group = 'MarkliveHeadingLineBg_' .. hl_group:gsub('[^%w_]', '_')
  vim.api.nvim_set_hl(0, group, { bg = bg })
  heading_bg_cache[group] = bg

  return group
end

local function render_heading_line_background(rc, hl_group)
  local line = rc.line
    or vim.api.nvim_buf_get_lines(rc.bufnr, rc.start_row, rc.start_row + 1, false)[1]
    or ''
  local line_byte_len = #line
  local line_width = vim.fn.strdisplaywidth(line)
  local win_width = tonumber(rc.win_width) or vim.api.nvim_win_get_width(0)

  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, 0, {
    end_line = rc.start_row,
    end_col = line_byte_len,
    hl_group = hl_group,
    priority = 0,
  })

  if win_width <= 0 then
    return
  end

  local fill_width = 0
  if line_width < win_width then
    fill_width = win_width - line_width
  else
    local remainder = line_width % win_width
    if remainder ~= 0 then
      fill_width = win_width - remainder
    end
  end

  if fill_width > 0 then
    vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, line_byte_len, {
      virt_text = { { string.rep(' ', fill_width), hl_group } },
      virt_text_pos = 'overlay',
      hl_mode = 'combine',
      priority = 0,
    })
  end
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


-- 自定义 block_quote 渲染
render.block_quote = function(rc)
  -- rc: { bufnr, namespace, hl_group, line, win_width, icon, start_row, start_col, end_row, end_col }
  local bufnr = rc.bufnr
  local namespace = rc.namespace
  local icon = rc.icon
  local hl_group = rc.hl_group
  local start_row = rc.start_row
  local end_row = rc.end_row
  local config = rc.config or require("marklive").config
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  if #lines == 0 then return end

  -- Extmarks in a block often share highlight groups; resolve each group only once.
  local highlights = {}
  local function get_highlight(group)
    if not group then
      return nil
    end
    if highlights[group] == nil then
      highlights[group] = vim.api.nvim_get_hl(0, { name = group, link = false }) or false
    end
    return highlights[group] or nil
  end

  local hl_def = get_highlight(hl_group)
  local bg = hl_def and hl_def.bg and string.format("#%06x", hl_def.bg) or nil

  -- 判断首行是否为 callout
  -- 如果 config.render.block_quote.callout 配置不为空，且首行为 > [!xxx]，则使用对应 callout 的 hl_group
  local callout_hl_group = nil
  local callout_icon = nil
  local callout_key = nil
  local callout_match_content = nil
  if config and config.render and config.render.block_quote and config.render.block_quote.callout then
    local first_line = lines[1]
    local callout_match, after = first_line:match("^%s*>%s*%[!([%w_%-]+)%](.*)")
    if callout_match then
      callout_key = string.lower(callout_match)
      for k, v in pairs(config.render.block_quote.callout) do
        if string.lower(k) == callout_key then
          callout_hl_group = v.hl_group
          callout_icon = v.icon
          break
        end
      end
      callout_match_content = after
    end
  end
  -- 优先使用 callout 的 hl_group 和 bg
  local use_hl_group = callout_hl_group or hl_group
  local use_bg = nil
  if callout_hl_group then
    local callout_hl = get_highlight(callout_hl_group)
    use_bg = callout_hl and callout_hl.bg and string.format("#%06x", callout_hl.bg) or nil
  end
  if not use_bg then
    use_bg = bg
  end

  for i, line in ipairs(lines) do
    local lnum = start_row + i - 1
    -- 查找第一个 '>'，并替换为 icon
    local gt_start, gt_end = line:find("^%s*>")
    if gt_start and gt_end then
      -- callout 特殊渲染逻辑（仅首行）
      if i == 1 and callout_icon and callout_key then
        -- 判断 [!key] 后是否有内容
        local after = callout_match_content or ""
        if after:match("^%s*$") then
          -- 仅 [!key]，如 > [!note]
          -- 1. conceal [ 替换为 icon
          local s1, e1 = line:find("%[")
          if s1 and e1 then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s1-1, {
              end_line = lnum,
              end_col = e1,
              conceal = callout_icon,
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 2. conceal ! 替换为空格
          local s_ex, e_ex = line:find("!", (e1 or 0) + 1)
          if s_ex and e_ex then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s_ex-1, {
              end_line = lnum,
              end_col = e_ex,
              conceal = " ",
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 3. conceal ] 替换为 ''
          local s2, e2 = line:find("%]", (e_ex or 0) + 1)
          if s2 and e2 then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s2-1, {
              end_line = lnum,
              end_col = e2,
              conceal = "",
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 4. conceal key（如 note），每个字符单独conceal，首字母大写，其余小写
          local key_str = line:match("%[!([%w_%-]+)%]")
          if key_str then
            local key_start = line:find('[!' .. key_str .. ']', 1, true)
            if key_start then
              for idx = 1, #key_str do
                local char_col = key_start + 1 + idx -- [! 占2位
                local char = key_str:sub(idx, idx)
                vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, char_col - 1, {
                  end_line = lnum,
                  end_col = char_col,
                  conceal = idx == 1 and char:upper() or char:lower(),
                  hl_group = callout_hl_group,
                  priority = 0,
                })
              end
            end
            -- conceal [!key] 中的所有空格
            local key_match = line:match("(%[![%w_%-]+%])")
            if key_match then
              local key_start = line:find(key_match, 1, true)
              for idx = 1, #key_match do
                if key_match:sub(idx, idx) == " " then
                  vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, key_start + idx - 2, {
                    end_line = lnum,
                    end_col = key_start + idx - 1,
                    conceal = "",
                    hl_group = callout_hl_group,
                    priority = 2,
                  })
                end
              end
            end
          end
        else
          -- [!key] 后有内容，如 > [!note] 标题
          -- 1. conceal [ 替换为 icon
          local s1, e1 = line:find("%[")
          if s1 and e1 then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s1-1, {
              end_line = lnum,
              end_col = e1,
              conceal = callout_icon,
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 2. conceal ! 替换为空格
          local s_ex, e_ex = line:find("!", (e1 or 0) + 1)
          if s_ex and e_ex then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s_ex-1, {
              end_line = lnum,
              end_col = e_ex,
              conceal = " ",
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 3. conceal key（如 note），每个字符单独conceal，首字母大写，其余小写
          local key_str = line:match("%[!([%w_%-]+)%]")
          if key_str then
            local key_start = line:find('[!' .. key_str .. ']', 1, true)
            if key_start then
              vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, key_start + 1, {
                end_line = lnum,
                end_col = key_start + #key_str + 1,
                conceal = '',
                hl_group = callout_hl_group,
                priority = 0,
              })
            end
          end
          -- 4. conceal ] 替换为 ''
          local s2, e2 = line:find("%]", (e_ex or 0) + 1)
          if s2 and e2 then
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, s2-1, {
              end_line = lnum,
              end_col = e2,
              conceal = "",
              hl_group = callout_hl_group,
              priority = 0,
            })
          end
          -- 5. 对自定义标题设置高亮，并将标题中的所有空格 conceal 掉
          if s2 and #line > e2 then
            -- conceal 标题中的所有空格
            local after_title = line:sub(e2 + 1)
            local offset = e2
            for idx = 1, #after_title do
              if after_title:sub(idx, idx) == " " then
                vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, offset + idx - 1, {
                  end_line = lnum,
                  end_col = offset + idx,
                  conceal = "",
                  hl_group = callout_hl_group,
                  priority = 2,
                })
              end
            end
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, e2, {
              end_line = lnum,
              end_col = #line,
              hl_group = callout_hl_group,
              priority = 1,
            })
          end
        end
      end

      -- callout 启用软折行续行前缀：每个换行显示同样的 block quote 竖线
      set_block_quote_marker(bufnr, namespace, lnum, gt_end, line, icon, use_hl_group, callout_key ~= nil)
    end

  end

  -- Scan the block once after marker extmarks have been added, preserving the
  -- background exclusion behavior without enumerating every namespace per line.
  local bg_to_use = use_bg or bg
  if not bg_to_use then
    return
  end

  local extmarks_by_line = {}
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, { start_row, 0 }, { end_row, 0 },
                                                  { details = true })
  for _, extmark in ipairs(extmarks) do
    local row = extmark[2]
    extmarks_by_line[row] = extmarks_by_line[row] or {}
    table.insert(extmarks_by_line[row], extmark)
  end

  local group_name = 'MarkliveBlockquoteBgOnly' .. (callout_key and '_' .. callout_key or '')
  pcall(vim.api.nvim_set_hl, 0, group_name, { bg = tonumber(bg_to_use:sub(2), 16) })

  local win_width = vim.api.nvim_win_get_width(0)
  for i, line in ipairs(lines) do
    local lnum = start_row + i - 1
    local line_byte_len = #line
    local bg_ranges = {}
    for _, extmark in ipairs(extmarks_by_line[lnum] or {}) do
      local details = extmark[4]
      local hl = details and get_highlight(details.hl_group)
      if hl and hl.bg then
        local start_col = extmark[3]
        local end_col = details.end_col or start_col + 1
        if start_col ~= end_col then
          table.insert(bg_ranges, { start_col, end_col })
        end
      end
    end

    table.sort(bg_ranges, function(a, b) return a[1] < b[1] end)
    local merged = {}
    for _, range in ipairs(bg_ranges) do
      if #merged == 0 or merged[#merged][2] < range[1] then
        table.insert(merged, { range[1], range[2] })
      else
        merged[#merged][2] = math.max(merged[#merged][2], range[2])
      end
    end

    -- Callout headers intentionally receive one uninterrupted background.
    if callout_key and i == 1 then
      merged = {}
    end

    local last = 0
    for _, range in ipairs(merged) do
      if last < range[1] then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, last, {
          end_line = lnum,
          end_col = range[1],
          hl_group = group_name,
          hl_mode = 'combine',
        })
      end
      last = range[2]
    end
    if last < line_byte_len then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, last, {
        end_line = lnum,
        end_col = line_byte_len,
        hl_group = group_name,
        hl_mode = 'combine',
      })
    end

    local line_len = vim.fn.strdisplaywidth(line)
    local fill_width = 0
    if line_len < win_width then
      fill_width = win_width - line_len
    else
      local remainder = line_len % win_width
      if remainder ~= 0 then
        fill_width = win_width - remainder
      end
    end
    if fill_width > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, line_byte_len, {
        virt_text = { { string.rep(' ', fill_width), group_name } },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
      })
    end
  end
end

-- 节流渲染实现
local render_timers = {}
local query_cache = {}

local function cleanup_timer(bufnr)
  local timer = render_timers[bufnr]
  if not timer then
    return
  end

  timer:stop()
  if not timer:is_closing() then
    timer:close()
  end
  render_timers[bufnr] = nil
end

render.cleanup = function(bufnr)
  if bufnr ~= nil then
    cleanup_timer(bufnr)
    table_layout_cache_by_buf[bufnr] = nil
    return
  end

  for buffer in pairs(render_timers) do
    cleanup_timer(buffer)
  end
  for buffer in pairs(table_layout_cache_by_buf) do
    table_layout_cache_by_buf[buffer] = nil
  end
end

local function parse_query(lang, source)
  local key = lang .. '\n' .. source
  local cached = query_cache[key]
  if cached ~= nil then
    return cached or nil
  end

  local ok, query_obj = pcall(vim.treesitter.query.parse, lang, source)
  query_cache[key] = ok and query_obj or false
  return query_cache[key] or nil
end

render.throttle_init = function(namespace, config, query, regex_list)
  local bufnr = vim.api.nvim_get_current_buf()
  local timer = render_timers[bufnr]
  if not timer then
    timer = vim.loop.new_timer()
    render_timers[bufnr] = timer
  end
  timer:stop()

  local delay = 10
  if config and config.render_delay then
    delay = config.render_delay
  end
  timer:start(delay, 0, vim.schedule_wrap(function()
    if render_timers[bufnr] ~= timer then
      return
    end
    render._init_visible(bufnr, namespace, config, query, regex_list)
  end))
end

-- 只渲染可见区域
render._init_visible = function(bufnr, namespace, config, query, regex_list)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  local valid_filetypes = config.filetype
  if type(valid_filetypes) == "string" then
    valid_filetypes = { valid_filetypes }
  end
  -- 统一 filetype 大小写
  local filetype_lower = string.lower(filetype)
  local found = false
  for _, ft in ipairs(valid_filetypes) do
    if filetype_lower == string.lower(ft) then
      found = true
      break
    end
  end
  -- print("[marklive] 当前 filetype: " .. tostring(filetype) .. "，是否满足要求: " .. tostring(found))
  if not found then
    -- print("[marklive] filetype 未命中，当前 filetype: " ..
    --   tostring(filetype) .. "，配置 filetype 列表: " .. vim.inspect(valid_filetypes))
    return
  end
  -- 收集所有显示该 buffer 的窗口的可视行范围 (0-based start, 1-based end)，并合并
  local visible_ranges = {}
  local max_width = 0
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      vim.api.nvim_win_call(winid, function()
        local tl = vim.fn.line('w0') - 1      -- 0-based
        local bl = vim.fn.line('w$')          -- 1-based (treesitter 结束行使用独占行号, 直接复用)
        table.insert(visible_ranges, { tl, bl })
        local w = vim.api.nvim_win_get_width(0)
        if w > max_width then max_width = w end
      end)
    end
  end
  if #visible_ranges == 0 then return end

  table.sort(visible_ranges, function(a, b) return a[1] < b[1] end)
  local merged_ranges = {}
  for _, r in ipairs(visible_ranges) do
    if #merged_ranges == 0 or merged_ranges[#merged_ranges][2] < r[1] then
      table.insert(merged_ranges, { r[1], r[2] })
    else
      if r[2] > merged_ranges[#merged_ranges][2] then
        merged_ranges[#merged_ranges][2] = r[2]
      end
    end
  end
  visible_ranges = merged_ranges
  local width = max_width
  table_ranges_by_buf[bufnr] = {}

  for _, range in ipairs(visible_ranges) do
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, range[1], range[2])
  end

  local ts = vim.treesitter
  local parser
  local ts_lang = filetype
  local ok, err = pcall(function()
    parser = ts.get_parser(bufnr, ts_lang)
  end)
  if not ok or not parser then
    ts_lang = "markdown"
    ok, err = pcall(function()
      parser = ts.get_parser(bufnr, ts_lang)
    end)
    if not ok or not parser then
      -- markdown 也失败，直接返回
      return
    end
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  local query_obj
  local markdown_query = query
  local italic_config = config.render.italic
  local has_italic_query = italic_config
    and italic_config.render == 'italic'
    and type(italic_config.query) == 'string'
  if has_italic_query then
    -- Emphasis belongs to markdown_inline, so keep it out of the host query.
    markdown_query = markdown_query:gsub(vim.pesc(italic_config.query), '')
  end
  query_obj = parse_query(ts_lang, markdown_query)
  if not query_obj then
    -- 解析 query 失败，尝试用 markdown 解析
    if ts_lang ~= "markdown" then
      ts_lang = "markdown"
      query_obj = parse_query(ts_lang, markdown_query)
      if not query_obj then
        return
      end
    else
      return
    end
  end

  local fenced_ranges = {}
  local fenced_query = parse_query(ts_lang, '(fenced_code_block) @fenced')
  if fenced_query then
    local seen_fenced_ranges = {}
    local function add_fenced_range(node)
      while node and node:type() ~= 'fenced_code_block' do
        node = node:parent()
      end
      if not node then
        return
      end

      local start_row, _, end_row = node:range()
      local key = start_row .. ':' .. end_row
      if not seen_fenced_ranges[key] then
        seen_fenced_ranges[key] = true
        table.insert(fenced_ranges, { start_row, end_row })
      end
    end

    for _, range in ipairs(visible_ranges) do
      if range[1] < range[2] then
        add_fenced_range(root:named_descendant_for_range(range[1], 0, range[1], 0))
      end
      for _, node in fenced_query:iter_captures(root, bufnr, range[1], range[2]) do
        add_fenced_range(node)
      end
    end
  end

  local function is_fenced_row(row)
    for _, range in ipairs(fenced_ranges) do
      if row >= range[1] and row < range[2] then
        return true
      end
    end
    return false
  end

  if has_italic_query then
    -- Limit inline parsing to Markdown inline nodes to exclude fenced code blocks.
    local inline_parser
    local inline_query
    local inline_ranges = {}
    ok = pcall(function()
      inline_parser = ts.get_parser(bufnr, 'markdown_inline')
      inline_query = parse_query('markdown_inline', italic_config.query)
    end)

    if ok and inline_parser and inline_query then
      local host_inline_query = parse_query(ts_lang, '(inline) @inline')
      if host_inline_query then
        for _, range in ipairs(visible_ranges) do
          for _, node in host_inline_query:iter_captures(root, bufnr, range[1], range[2]) do
            table.insert(inline_ranges, { node:range() })
          end
        end
      end

      local inline_tree = inline_parser:parse()[1]
      local inline_root = inline_tree:root()
      for _, range in ipairs(inline_ranges) do
        for _, node in inline_query:iter_captures(inline_root, bufnr, range[1], range[3]) do
          local start_row, start_col, end_row, end_col = node:range()
          if not is_fenced_row(start_row) then
            render.italic({
              bufnr = bufnr,
              namespace = namespace,
              hl_group = italic_config.hl_group or 'italic',
              start_row = start_row,
              start_col = start_col,
              end_row = end_row,
              end_col = end_col,
            })
          end
        end
      end
    end
  end

  for _, range in ipairs(visible_ranges) do
    local range_start = range[1]
    local range_end = range[2]
    for id, node in query_obj:iter_captures(root, bufnr, range_start, range_end) do
      local name = query_obj.captures[id]
      local icon = type(config.render[name].icon) == "table" and config.render[name].icon[1] or
          config.render[name].icon
      local hl_group = config.render[name].hl_group or name
      local start_row, start_col, end_row, end_col = node:range()
      local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
      local line_length = #line
      local icon_padding = config.render[name].icon_padding

      -- 多窗口可视区域合并后渲染；保持原有代码块跳过逻辑
      if name ~= "code_block" and is_fenced_row(start_row) then
        goto continue_query
      end

      if type(config.render[name].render) == "function" then
        config.render[name].render({
          bufnr = bufnr,
          namespace = namespace,
          config = config,
          name = name,
          render_config = config.render[name],
          indent = config.render[name].indent,
          hl_group = hl_group,
          line = line,
          win_width = width,
          icon = icon,
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
        })
      elseif type(config.render[name].render) == 'string' and type(render[config.render[name].render]) ~= 'nil' then
        render[config.render[name].render]({
          bufnr = bufnr,
          namespace = namespace,
          config = config,
          name = name,
          render_config = config.render[name],
          indent = config.render[name].indent,
          hl_group = hl_group,
          line = line,
          win_width = width,
          icon = icon,
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
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
            hl_group = hl_group,
            priority = 0,
          })
          local after_hl = config.render[name].after_highlight
          if after_hl ~= nil and after_hl ~= false then
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
            virt_text = { { fill_content:rep(math.max(0, width - line_length - 1)), hl_group } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        end
      end
      ::continue_query::
    end
  end

  for name, regex in pairs(regex_list) do
    local icon = config.render[name].icon or ''
    for _, range in ipairs(visible_ranges) do
      local r_start = range[1]
      local r_end = range[2]
        local lines = vim.api.nvim_buf_get_lines(bufnr, r_start, r_end, false)
      local matches = utils.find_matches_with_groups(lines, regex)
      for _, match in ipairs(matches) do
        local lnum = r_start + match.lnum
        if is_fenced_row(lnum) then
          goto continue_regex
        end
        if #match.groups == 0 then
          local hl_group = config.render[name].hl_group or name
          vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, match.start_col, {
            end_line = lnum,
            end_col = match.end_col,
            conceal = type(icon) == "table" and icon[1] or icon,
            hl_group = hl_group,
            priority = 0,
          })
        else
          for i, group in ipairs(match.groups) do
            local hl_group = config.render[name].hl_group or name
            local conceal = type(icon) == "table" and icon[i] or icon
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, group.start_col, {
              end_line = lnum,
              end_col = group.end_col + 1,
              conceal = conceal,
              hl_group = hl_group,
              priority = config.render[name].priority or 0,
            })
          end

          if name == 'inline_code' then
            local hl_group = config.render[name].hl_group or name
            -- 内联代码需要覆盖整段（含内容）高亮，避免被 block_quote/callout 背景吞掉
            vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, match.start_col, {
              end_line = lnum,
              end_col = match.end_col + 1,
              hl_group = hl_group,
              priority = 5000,
            })
          end
        end
        ::continue_regex::
      end
    end
  end
end

-- 兼容原有接口
render.init = render.throttle_init

render.list = function(rc)
  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.end_col - 2, {
    end_line = rc.end_row,
    end_col = rc.end_col - 1,
    conceal = rc.icon,
    hl_group = rc.hl_group, -- use_name
    priority = 0,           -- To ignore conceal hl_group when focused
  })
end

render.italic = function(rc)
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
end

-- 仅使用 conceal 很难实现列的等宽, 考虑使用 virt_text 来实现, 但是要考虑到性能(支持光标所在行显示源码)
---@param rc table
render.table = function(rc)
  -- 定义高亮组
  local border_hl = "MarkliveTableBorder"
  local header_hl = "MarkliveTableHeader"

  if not table_highlights_initialized then
    vim.api.nvim_set_hl(0, border_hl, { fg = "#ef9020" })
    vim.api.nvim_set_hl(0, header_hl, { fg = "#ef9020", bold = true })
    table_highlights_initialized = true
  end

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
  local layout = get_table_layout(bufnr, start_row, end_row)
  local table_cells = layout.table_cells
  local column_max_width = layout.column_max_width
  local col_count = layout.col_count
  local alignments = layout.alignments

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

  -- 根据 config.render 配置动态处理 markdown 行内符号隐藏和分段高亮
  local function conceal_markdown_cell(cell, bufnr, row_idx, col_idx, config)
    -- 返回形如 { {text, hl_group}, ... }
    local patterns = {
      -- 优先使用 config.render 里的 regex 配置
      -- 格式: { pattern, hl_group }
      -- pattern 必须带捕获组
    }
    -- 兜底：常见语法
    table.insert(patterns, { "(`)(.-)(`)", "markdownCode" })
    table.insert(patterns, { "(%*%*)(.-)(%*%*)", "markdownBold" })
    table.insert(patterns, { "(_)(.-)(_)", "markdownItalic" })
    table.insert(patterns, { "(~~)(.-)(~~)", "markdownStrike" })
    table.insert(patterns, { "(<u>)(.-)(</u>)", nil })
    table.insert(patterns, { "(<mark>)(.-)(</mark>)", nil })
    table.insert(patterns, { "(<b>)(.-)(</b>)", "markdownBold" })

    -- 递归分段（修正高亮范围问题，优先最长匹配，避免嵌套错乱）
    local function split_segments(str, pat_idx)
      if pat_idx > #patterns then
        return { { str } }
      end
      local pattern, hl_group = patterns[pat_idx][1], patterns[pat_idx][2]
      local res = {}
      local last_end = 1
      local found = false
      while true do
        local s, e, left, mid, right = str:find(pattern, last_end)
        if not s then break end
        found = true
        if s > last_end then
          -- 前段
          local before = str:sub(last_end, s - 1)
          vim.list_extend(res, split_segments(before, pat_idx + 1))
        end
        -- 中间内容
        if mid and #mid > 0 then
          if hl_group == "markdownCode" then
            table.insert(res, { " " .. mid .. " ", hl_group })
          else
            table.insert(res, { mid, hl_group })
          end
        end
        last_end = e + 1
      end
      if found and last_end <= #str then
        local after = str:sub(last_end)
        vim.list_extend(res, split_segments(after, pat_idx + 1))
      elseif not found then
        -- 如果本 pattern 没有匹配，递归下一个 pattern
        return split_segments(str, pat_idx + 1)
      end
      return res
    end

    return split_segments(cell, 1)
  end

  -- 构造内容行
  local function make_content_row(row_cells, is_header)
    local row = {}
    table.insert(row, { border[10], border_hl })
    for i = 1, col_count do
      local cell = row_cells[i] or ""
      -- 对 cell 做 markdown 语法符号隐藏和分段高亮
      local segments = conceal_markdown_cell(cell, bufnr, i, i, rc.config)
      -- 计算内容宽度
      local cell_width = 0
      for _, seg in ipairs(segments) do
        cell_width = cell_width + vim.fn.strdisplaywidth(seg[1])
      end
      local pad = column_max_width[i] - cell_width
      local align = alignments[i] or "left"
      local left_extra, right_extra
      if align == "center" then
        left_extra = math.floor(pad / 2)
        right_extra = pad - left_extra
      elseif align == "right" then
        left_extra = pad
        right_extra = 0
      else
        left_extra = 0
        right_extra = pad
      end
      -- 拼接分段
      if is_header then
        table.insert(row, { string.rep(" ", 1 + left_extra), header_hl })
        for _, seg in ipairs(segments) do
          table.insert(row, { seg[1], seg[2] or header_hl })
        end
        table.insert(row, { string.rep(" ", 1 + right_extra), header_hl })
      else
        table.insert(row, { string.rep(" ", 1 + left_extra) })
        for _, seg in ipairs(segments) do
          table.insert(row, { seg[1], seg[2] })
        end
        table.insert(row, { string.rep(" ", 1 + right_extra) })
      end
      table.insert(row, { border[10], border_hl })
    end
    return row
  end

  -- 优化：表格内只有光标所在行显示原文，其他行渲染表格
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1

  -- 渲染虚拟文本边框（不占用实际行）
  local win_width = vim.api.nvim_win_get_width(0)
  local virt_opts = {
    virt_text_pos = "overlay",
    hl_mode = "replace",
  }

  -- 顶部边框和底部边框通过 virt_lines 渲染在表格首行上方和末行下方
  -- 先清除原有的顶部边框 extmark
  -- 渲染顶部边框
  vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, 0, {
    virt_lines = { top_border },
    virt_lines_above = true,
    hl_mode = "combine",
  })

  -- 内容行
  for i, row_cells in ipairs(table_cells) do
    local is_header = i == 1
    local line_idx = start_row + i - 1
    if cursor_row == line_idx then
      -- 光标所在行，显示原文（不渲染表格样式）
      -- 只清除该行的 extmark，由外部 autocmd 保证
    else
      local content = make_content_row(row_cells, is_header)
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
  end

  -- 底部边框通过 virt_lines 渲染在表格末行下方
  vim.api.nvim_buf_set_extmark(bufnr, namespace, end_row - 1, 0, {
    virt_lines = { bottom_border },
    virt_lines_above = false,
    hl_mode = "combine",
  })
end

-- 用于渲染 markdown 标题 marker
---@param rc table
render.heading_marker = function(rc)
  local render_config = rc.render_config or {}
  local line_bg_group = nil
  if render_config.line_background ~= false then
    if type(render_config.line_background) == 'string' then
      line_bg_group = render_config.line_background
    else
      line_bg_group = heading_line_bg_group(rc.hl_group)
    end

    if line_bg_group then
      render_heading_line_background(rc, line_bg_group)
    end
  end

  local indent = tonumber(rc.indent) or 0
  if indent > 0 then
    vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.start_col, {
      virt_text = { { string.rep(' ', indent), line_bg_group or rc.hl_group } },
      virt_text_pos = 'inline',
      hl_mode = 'combine',
      priority = 0,
    })
  end

  vim.api.nvim_buf_set_extmark(rc.bufnr, rc.namespace, rc.start_row, rc.start_col, {
    end_line = rc.end_row,
    end_col = rc.end_col,
    conceal = rc.icon,
    hl_group = rc.hl_group,
    priority = 0,
  })
end

-- 用于渲染 markdown 代码块
---@param rc table
render.code_block = function(rc)
  -- 高亮组定义
  local codeblock_hl = "MarkliveCodeblock"
  vim.api.nvim_set_hl(0, codeblock_hl, { bg = "#24283B" })

  local bufnr = rc.bufnr
  local namespace = rc.namespace
  local config = rc.config or require('marklive').config
  local code_block_config = config and config.render and config.render.code_block or {}
  local start_row = rc.start_row
  local end_row = rc.end_row
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  local first_line = lines[1] or ""
  local is_fenced_block = first_line:match("^%s*```+") ~= nil or first_line:match("^%s*~~~+") ~= nil
  local lang = extract_codeblock_language(first_line)

  -- 获取光标位置
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  local win_width = vim.api.nvim_win_get_width(0)

  local function highlight_line(lnum, line_content)
    local line_len = vim.fn.strdisplaywidth(line_content)
    local line_byte_len = string.len(line_content)
    vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, 0, {
      end_line = lnum,
      end_col = line_byte_len,
      hl_group = codeblock_hl,
      priority = 0,
    })
    if line_len < win_width then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, line_byte_len, {
        virt_text = { { string.rep(" ", win_width - line_len), codeblock_hl } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = 0,
      })
    end
  end

  local function overlay_line(lnum)
    vim.api.nvim_buf_set_extmark(bufnr, namespace, lnum, 0, {
      virt_text = { { string.rep(" ", win_width), codeblock_hl } },
      virt_text_pos = "overlay",
      hl_mode = "combine",
      priority = 0,
    })
  end

  if not is_fenced_block then
    for i = start_row, end_row - 1 do
      highlight_line(i, lines[i - start_row + 1] or "")
    end
    return
  end

  -- 只有 fenced code block 才会把首尾 fence 当作装饰行处理
  if cursor_row == start_row then
    highlight_line(start_row, lines[1] or "")
  else
    overlay_line(start_row)
  end

  if lang and lang ~= "" and cursor_row ~= start_row then
    local lang_style = get_codeblock_language_style(code_block_config.language_styles, lang)
    local lang_hl = lang_style.hl_group or codeblock_language_hl_group(lang)
    if not lang_style.hl_group then
      vim.api.nvim_set_hl(0, lang_hl, {
        bg = "#24283B",
        bold = true,
        fg = lang_style.fg or default_codeblock_language_style.fg,
      })
    end

    local icon = lang_style.icon or default_codeblock_language_style.icon
    local icon_text = icon ~= "" and icon .. " " or ""
    local lang_label = icon_text .. lang .. " "
    vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, 0, {
      virt_text = { { lang_label, lang_hl } },
      virt_text_pos = "overlay",
      hl_mode = "combine",
      priority = 20,
    })
  end

  if cursor_row == end_row - 1 then
    highlight_line(end_row - 1, lines[#lines] or "")
  else
    overlay_line(end_row - 1)
  end

  for i = start_row + 1, end_row - 2 do
    highlight_line(i, lines[i - start_row + 1] or "")
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

-- 表格渲染自动切换（normal模式下，光标进入表格取消渲染，离开表格重新渲染）
-- 包装原始 table 渲染函数，记录每个表格范围
local _orig_table = render.table

-- 新增：渲染表格单行（不渲染整表）
local function render_table_row(rc, row_idx)
  -- 只渲染表格的某一行
  local bufnr = rc.bufnr
  local namespace = rc.namespace
  local start_row = rc.start_row
  local end_row = rc.end_row
  local config = rc.config

  local border_hl = "MarkliveTableBorder"
  local header_hl = "MarkliveTableHeader"
  local border = {
    '┌', '┬', '┐',
    '├', '┼', '┤',
    '└', '┴', '┘',
    '│', '─',
  }

  local layout = get_table_layout(bufnr, start_row, end_row)
  local table_cells = layout.table_cells
  local column_max_width = layout.column_max_width
  local col_count = layout.col_count
  local alignments = layout.alignments

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

  local middle_border = make_border_row(border[4], border[5], border[6])

  local function conceal_markdown_cell(cell, bufnr, row_idx, col_idx, config)
    local patterns = {}
    table.insert(patterns, { "(`)(.-)(`)", "markdownCode" })
    table.insert(patterns, { "(%*%*)(.-)(%*%*)", "markdownBold" })
    table.insert(patterns, { "(_)(.-)(_)", "markdownItalic" })
    table.insert(patterns, { "(~~)(.-)(~~)", "markdownStrike" })
    table.insert(patterns, { "(<u>)(.-)(</u>)", nil })
    table.insert(patterns, { "(<mark>)(.-)(</mark>)", nil })
    table.insert(patterns, { "(<b>)(.-)(</b>)", "markdownBold" })

    local function split_segments(str, pat_idx)
      if pat_idx > #patterns then
        return { { str } }
      end
      local pattern, hl_group = patterns[pat_idx][1], patterns[pat_idx][2]
      local res = {}
      local last_end = 1
      local found = false
      while true do
        local s, e, left, mid, right = str:find(pattern, last_end)
        if not s then break end
        found = true
        if s > last_end then
          local before = str:sub(last_end, s - 1)
          vim.list_extend(res, split_segments(before, pat_idx + 1))
        end
        if mid and #mid > 0 then
          if hl_group == "markdownCode" then
            table.insert(res, { " " .. mid .. " ", hl_group })
          else
            table.insert(res, { mid, hl_group })
          end
        end
        last_end = e + 1
      end
      if found and last_end <= #str then
        local after = str:sub(last_end)
        vim.list_extend(res, split_segments(after, pat_idx + 1))
      elseif not found then
        return split_segments(str, pat_idx + 1)
      end
      return res
    end

    return split_segments(cell, 1)
  end

  local function make_content_row(row_cells, is_header)
    local row = {}
    table.insert(row, { border[10], border_hl })
    for i = 1, col_count do
      local cell = row_cells[i] or ""
      local segments = conceal_markdown_cell(cell, bufnr, i, i, config)
      local cell_width = 0
      for _, seg in ipairs(segments) do
        cell_width = cell_width + vim.fn.strdisplaywidth(seg[1])
      end
      local pad = column_max_width[i] - cell_width
      local align = alignments[i] or "left"
      local left_extra, right_extra
      if align == "center" then
        left_extra = math.floor(pad / 2)
        right_extra = pad - left_extra
      elseif align == "right" then
        left_extra = pad
        right_extra = 0
      else
        left_extra = 0
        right_extra = pad
      end
      if is_header then
        table.insert(row, { string.rep(" ", 1 + left_extra), header_hl })
        for _, seg in ipairs(segments) do
          table.insert(row, { seg[1], seg[2] or header_hl })
        end
        table.insert(row, { string.rep(" ", 1 + right_extra), header_hl })
      else
        table.insert(row, { string.rep(" ", 1 + left_extra) })
        for _, seg in ipairs(segments) do
          table.insert(row, { seg[1], seg[2] })
        end
        table.insert(row, { string.rep(" ", 1 + right_extra) })
      end
      table.insert(row, { border[10], border_hl })
    end
    return row
  end

  -- 只渲染指定行
  local i = row_idx - start_row + 1
  if i < 1 or i > #table_cells then return end
  local is_header = i == 1
  local content = make_content_row(table_cells[i], is_header)
  local line_idx = row_idx
  local orig_line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1] or ""
  local orig_width = vim.fn.strdisplaywidth(orig_line)
  local render_width = 0
  for _, seg in ipairs(content) do
    render_width = render_width + vim.fn.strdisplaywidth(seg[1])
  end
  local fill = ""
  if render_width < orig_width then
    fill = string.rep(" ", orig_width - render_width)
    table.insert(content, { fill })
  end

  local virt_opts = {
    virt_text_pos = "overlay",
    hl_mode = "replace",
  }

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

render.table = function(rc)
  local bufnr = rc.bufnr
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_row = rc.start_row
  local end_row = rc.end_row

  while start_row > 0 do
    local prev_line = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, start_row, false)[1]
    if is_pipe_table_line(prev_line) then
      start_row = start_row - 1
    else
      break
    end
  end
  while end_row < line_count do
    local next_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
    if is_pipe_table_line(next_line) then
      end_row = end_row + 1
    else
      break
    end
  end
  rc.start_row = start_row
  rc.end_row = end_row

  if not table_ranges_by_buf[bufnr] then
    table_ranges_by_buf[bufnr] = {}
  end
  local merged = false
  for idx, range in ipairs(table_ranges_by_buf[bufnr]) do
    if not (end_row <= range.start_row or start_row >= range.end_row) then
      range.start_row = start_row
      range.end_row = end_row
      rc.start_row = start_row
      rc.end_row = end_row
      merged = true
      -- 清理旧渲染范围
      vim.api.nvim_buf_clear_namespace(bufnr, rc.namespace, range.start_row, range.end_row)
      break
    end
  end
  if not merged then
    table.insert(table_ranges_by_buf[bufnr], {
      start_row = start_row,
      end_row = end_row,
      bufnr = rc.bufnr,
      namespace = rc.namespace,
      config = rc.config,
    })
    rc.start_row = start_row
    rc.end_row = end_row
    vim.api.nvim_buf_clear_namespace(bufnr, rc.namespace, rc.start_row, rc.end_row)
  end

  _orig_table(rc)
end

-- 监听光标移动
-- 只重渲染光标离开和进入的行，避免全表格闪烁
local last_cursor_row = nil
local last_cursor_bufnr = nil

render.handle_table_cursor = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local table_ranges = table_ranges_by_buf[bufnr] or {}
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1

  -- 只在行号变化时处理
  if last_cursor_row == cursor_row and last_cursor_bufnr == bufnr then
    return true
  end

  local prev_row = last_cursor_row
  local prev_bufnr = last_cursor_bufnr
  last_cursor_row = cursor_row
  last_cursor_bufnr = bufnr

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local handled = false
  local needs_full_render = false
  local function clear_and_rerender_row(row)
    if row == nil or row < 0 or row >= line_count then return end
    for _, tbl in ipairs(table_ranges) do
      if row >= tbl.start_row and row < tbl.end_row then
        -- 跳过表格首行和末行，避免清除虚拟包裹行，防止闪烁
        if row == tbl.start_row or row == tbl.end_row - 1 then
          needs_full_render = true
          return
        end
        -- 只清除并重渲染该行
        vim.api.nvim_buf_clear_namespace(tbl.bufnr, tbl.namespace, row, row + 1)
        if render_table_row then
          render_table_row(tbl, row)
          handled = true
        end
        break
      end
    end
  end

  -- 只处理离开和进入的行
  if prev_row ~= nil and prev_bufnr == bufnr and prev_row ~= cursor_row then
    clear_and_rerender_row(prev_row)
  end
  clear_and_rerender_row(cursor_row)

  local function is_fence_row(row)
    if row == nil or row < 0 or row >= line_count then
      return false
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
    return line:match('^%s*```+') ~= nil or line:match('^%s*~~~+') ~= nil
  end

  -- Only tables and fence decorations depend on the cursor row. Concealcursor
  -- handles every other element without rebuilding all visible extmarks.
  return not needs_full_render
    and (handled or not (is_fence_row(prev_row) or is_fence_row(cursor_row)))
end

-- 让 code_block 能访问表格信息
render._table_ranges_by_buf = table_ranges_by_buf
render._table_layout_cache_by_buf = table_layout_cache_by_buf

local _cleanup = render.cleanup
render.cleanup = function(bufnr)
  _cleanup(bufnr)
  if bufnr ~= nil then
    table_ranges_by_buf[bufnr] = nil
    if last_cursor_bufnr == bufnr then
      last_cursor_bufnr = nil
      last_cursor_row = nil
    end
    return
  end

  for buffer in pairs(table_ranges_by_buf) do
    table_ranges_by_buf[buffer] = nil
  end
  last_cursor_bufnr = nil
  last_cursor_row = nil
end

return render
