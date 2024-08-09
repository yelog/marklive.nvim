local default_config = require('marklive.config')
local utils = require('marklive.utils')
local render = require('marklive.render')
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

  -- enable marklive
  if M.config.enable then
    M.enable()
  end
end

M.render = function()
  render(M.namespace, M.config, query, regex_list)
end


M.enable = function()
  M.render();
  M.config.enable = true

  -- set highlight
  utils.setHighlight(M.config.highlight_config or {}, M.config.filetype)

  vim.cmd [[
        augroup Marklive
        autocmd FileChangedShellPost,Syntax,TextChanged,InsertLeave,TextChangedI * lua require('marklive').render()
        augroup END
    ]]
end

M.disable = function()
  M.config.enable = false
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
vim.api.nvim_command [[command! MarkliveEnable lua require('marklive').render()]]
vim.api.nvim_command [[command! MarkliveDisable lua require('marklive').disable()]]
vim.api.nvim_command [[command! MarkliveToggle lua require('marklive').toggle()]]

return M
