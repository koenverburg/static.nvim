local utils = require('static.utils')
local config = require('static.config')

local M = {}

local function_queriess = [[
  (arrow_function) @captures
  (method_definition) @captures
  (lexical_declaration) @captures
  (function_declaration) @captures
  (generator_function_declaration) @captures
]]
local exit_queries = [[ (return_statement) @captures ]]

local function query_for_returns(namespace, bufnr, lang, function_tree)
  if lang == "typescriptreact" then
    lang = "tsx"
  end

  local parsed = vim.treesitter.query.parse(lang, exit_queries)

  for _, match in parsed:iter_matches(function_tree, bufnr) do
    for _, node in pairs(match) do
      local func_end = tostring(function_tree:end_() - 1)
      local node_end = tostring(node:end_())
      local line, col, _ = node:start()
      if func_end == node_end then
        utils.setVirtualText(namespace, line, col, "original exit", config.signs.info.icon, nil) -- signs.info.highlightGroup)
      else
        utils.setVirtualText(namespace, line, col, "early exit", config.signs.info.icon, nil)    -- signs.info.highlightGroup)
      end
    end
  end
end

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  if not utils.enabled_when_supprted_filetype(config.supported_filetypes, bufnr) then
    return utils.noop
  end

  local parser, parsed, root = utils.query_buffer(bufnr, function_queriess)
  if not parsed then
    return utils.noop
  end
  for _, match in parsed:iter_matches(root, bufnr) do
    for _, node in pairs(match) do
      if not parser then
        vim.notify("parser not found")
        return utils.noop
      end
      query_for_returns(config.namespace.ns_early_exit, bufnr, parser:lang(), node)
    end
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_early_exit, 0, -1)
end

return M
