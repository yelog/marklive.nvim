local default_config = require('marklive.config')
local utils = require('marklive.utils')
local render = require('marklive.render')
local action = require('marklive.action')
local M = {}
-- 暴露全局引用，便于在按键映射等场景直接调用
_G.Marklive = M
-- treesitter query
local query = ""
local regex_list = {}
M.namespace = vim.api.nvim_create_namespace "marklive_namespace"
M.config = default_config

M.apply_highlights = function()
  for name, renderConfig in pairs(M.config.render) do
    if renderConfig.highlight ~= nil then
      vim.api.nvim_set_hl(0, name, renderConfig.highlight)
    end
  end

  utils.applyHighlight(M.config.highlight_config or {})
end

M.is_renderable_buffer = function(bufnr)
  if not M.config.enable or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local filetype = vim.bo[bufnr].filetype:lower()
  local filetypes = M.config.filetype
  if type(filetypes) == 'string' then
    filetypes = { filetypes }
  end
  for _, candidate in ipairs(filetypes) do
    if filetype == candidate:lower() then
      return true
    end
  end
  return false
end

M.setup = function(config)
  -- merge config
  config = config or {}
  M.config = vim.tbl_deep_extend("force", M.config, config)

  -- Handle after_highlight override in render config
  if config.render then
    for name, user_render in pairs(config.render) do
      if user_render.after_highlight == nil then
        if M.config.render[name] then
          M.config.render[name].after_highlight = nil
        end
      end
    end
  end

  -- generate query and regex
  local generate_result = utils.generate_query_regex(M.config.render)
  query = generate_result.query
  regex_list = generate_result.regex_list

  -- set item highlight
  M.apply_highlights()

  -- conceal config
  vim.wo.conceallevel = 2
  vim.wo.cole = vim.wo.conceallevel
  if M.config.show_mode == 'insert-line' then
    vim.opt.concealcursor = 'nc'
  elseif M.config.show_mode == 'normal-line' then
    vim.opt.concealcursor = ''
  else
    vim.opt.concealcursor = 'nc'
  end

  if not M.config.enable then
    action.setup_list_autocmd()
    return
  end

  -- enable marklive
  if M.config.enable then
    M.enable()
  end
end

-- 使用节流和可见区域渲染
M.render = function()
  if not M.is_renderable_buffer(vim.api.nvim_get_current_buf()) then
    return
  end
  render.init(M.namespace, M.config, query, regex_list)
end


M.enable = function()
  M.config.enable = true
  action.setup_list_autocmd()
  M.render()

  -- set highlight
  utils.setHighlight(M.config.highlight_config or {}, vim.o.filetype)

  local group = vim.api.nvim_create_augroup('Marklive', { clear = true })
  local render_events = {
    'FileChangedShellPost', 'Syntax', 'TextChanged', 'InsertLeave', 'TextChangedI',
    'CursorMoved', 'CursorMovedI', 'WinScrolled',
  }
  if vim.fn.exists('##FoldChanged') == 1 then
    table.insert(render_events, 'FoldChanged')
  end
  vim.api.nvim_create_autocmd(render_events, {
    group = group,
    callback = function(args)
      if M.is_renderable_buffer(args.buf) then
        M.render()
      end
    end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      M.apply_highlights()
      M.render()
    end,
  })
end

M.disable = function()
  M.config.enable = false
  action.setup_list_autocmd()
  vim.api.nvim_buf_clear_namespace(0, M.namespace, 0, -1)

  -- clear highlight
  utils.clearHighlight(M.config.filetype)

  -- clear augroup
  vim.cmd [[
        augroup Marklive
        autocmd!
        augroup END
    ]]
end

M.toggle = function()
  if M.config.enable then
    M.disable()
  else
    M.enable()
  end
end

-- register vim command
vim.api.nvim_create_user_command("MarkliveEnable", function()
  require('marklive').render()
end, { desc = "Enable Marklive rendering" })

vim.api.nvim_create_user_command("MarkliveDisable", function()
  require('marklive').disable()
end, { desc = "Disable Marklive rendering" })

vim.api.nvim_create_user_command("MarkliveToggle", function()
  require('marklive').toggle()
end, { desc = "Toggle Marklive rendering" })

vim.api.nvim_create_user_command("MarkliveTaskToggle", function()
  require("marklive.action").toggle_task()
end, { desc = "Toggle markdown task state" })

M.table_align = function()
  require("marklive.action").table_align()
end

M.table_insert_row_below = function()
  require("marklive.action").table_insert_row_below()
end

M.table_insert_row_above = function()
  require("marklive.action").table_insert_row_above()
end

M.table_insert_col_right = function()
  require("marklive.action").table_insert_col_right()
end

M.table_insert_col_left = function()
  require("marklive.action").table_insert_col_left()
end

M.table_move_col_left = function()
  require("marklive.action").table_move_col_left()
end

M.table_move_col_right = function()
  require("marklive.action").table_move_col_right()
end

M.table_move_row_down = function()
  require("marklive.action").table_move_row_down()
end

M.table_move_row_up = function()
  require("marklive.action").table_move_row_up()
end

M.table_delete_row = function()
  require("marklive.action").table_delete_row()
end

M.table_delete_col = function()
  require("marklive.action").table_delete_col()
end

M.table_nav_left = function()
  require("marklive.action").table_nav_left()
end

M.table_nav_right = function()
  require("marklive.action").table_nav_right()
end

M.table_nav_up = function()
  require("marklive.action").table_nav_up()
end

M.table_nav_down = function()
  require("marklive.action").table_nav_down()
end

return M
