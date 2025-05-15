local utils = require('static.utils')
local config = require('static.config')

local M = {}

local query_string = [[
  (return_statement) @return
]]

local function get_enclosing_function(node)
  while node do
    local t = node:type()
    if t == "function_declaration" or
       t == "function_definition" or
       t == "function_expression" or
       t == "method_declaration" then
      return node
    end
    node = node:parent()
  end
  return nil
end

local function get_final_return_node(func_node)
  if not func_node then return nil end

  local block = nil
  for child in func_node:iter_children() do
    if child:type() == "block" then
      block = child
      break
    end
  end
  if not block then return nil end

  local last_return = nil
  for child in block:iter_children() do
    if child:type() == "return_statement" then
      last_return = child
    end
  end
  return last_return
end

local function is_early_return(node)
  local function_node = node

  while function_node do
    local type = function_node:type()
    if type == "function_declaration" or type == "function_definition" or
       type == "method_declaration" or type == "function_expression" then
      break
    end
    function_node = function_node:parent()
  end

  if not function_node then return false end

  local block = nil
  for child in function_node:iter_children() do
    if child:type() == "block" then
      block = child
      break
    end
  end

  if not block then return false end

  local last_statement = nil
  for child in block:iter_children() do
    if child:type() ~= "comment" then
      last_statement = child
    end
  end

  return last_statement and not last_statement:id() == node:id()
end

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, config.namespace.ns_early_exit, 0, -1)

  local lang = vim.bo[bufnr].filetype
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then return end

  local tree = parser:parse()[1]
  if not tree then return end
  local root = tree:root()

  local query = vim.treesitter.query.parse(lang, query_string)

  local seen = {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    if query.captures[id] ~= "return" then goto continue end

    local func_node = get_enclosing_function(node)
    local final_return = get_final_return_node(func_node)

    local func_end = tostring(func_node:end_() - 1)
    local node_end = tostring(node:end_())

    local is_final = func_end == node_end

    if not seen[node:id()] then
      seen[node:id()] = true

      local line, col, _ = node:start()

      if is_final then
        utils.setVirtualText(bufnr, config.namespace.ns_early_exit, line, col, "final return", config.signs.info.icon, "Comment")
      else
        utils.setVirtualText(bufnr, config.namespace.ns_early_exit, line, col, "early return", config.signs.info.icon, "DiagnosticHint")
      end
    end

    ::continue::
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_early_exit, 0, -1)
end

return M
