local default_config = require('marklive.config')
local utils = require('marklive.utils')
local render = require('marklive.render')
local action = require('marklive.action')
local M = {}
-- treesitter query
local query = ""
local regex_list = {}
M.namespace = vim.api.nvim_create_namespace "marklive_namespace"
M.config = default_config

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
  for name, renderConfig in pairs(M.config.render) do
    if renderConfig.highlight ~= nil then
      vim.api.nvim_set_hl(0, name, renderConfig.highlight)
    end
  end

  if M.config.highlight_config then
    for name, config in pairs(M.config.highlight_config) do
      if config.highlight ~= nil then
        vim.api.nvim_set_hl(0, name, config.highlight)
      end
    end
  end

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
  render.init(M.namespace, M.config, query, regex_list)
end


M.enable = function()
  M.config.enable = true
  action.setup_list_autocmd()
  M.render()

  -- set highlight
  utils.setHighlight(M.config.highlight_config or {}, vim.o.filetype)

  vim.cmd [[
        augroup Marklive
        autocmd!
        autocmd FileChangedShellPost,Syntax,TextChanged,InsertLeave,TextChangedI * lua require('marklive').render()
        autocmd CursorMoved,CursorMovedI * lua require('marklive').render()
        " 当折叠被打开或关闭时，可视区域发生变化但光标可能未移动，需要重新渲染
        " WinScrolled: 部分情况下展开折叠会引起窗口滚动（顶部/底部补行）
        autocmd WinScrolled * lua require('marklive').render()
        " 仅在存在 FoldChanged 事件 (NVIM 0.10+) 时注册
        if exists('##FoldChanged')
          autocmd FoldChanged * lua require('marklive').render()
        endif
        " 兜底：在没有 FoldChanged 且不滚动/不移动光标的折叠场景，用 CursorHold 触发（受 updatetime 影响）
        autocmd CursorHold,CursorHoldI * lua require('marklive').render()
        augroup END
    ]]
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

return M
