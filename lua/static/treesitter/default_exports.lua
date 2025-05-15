local utils = require('static.utils')
local config = require('static.config')

local M = {}

local query_string = [[
  (export_statement) @captures
]]

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()

  local lang = vim.bo[bufnr].filetype
  if not (lang == "javascript" or lang == "typescript" or lang == "javascriptreact" or lang == "typescriptreact") then return end

  local parser = vim.treesitter.get_parser(bufnr, lang)
  local tree = parser:parse()[1]
  local root = tree:root()
  local query = vim.treesitter.query.parse(lang, query_string)

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local row, col = node:range()
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

    if line:match("export%s+default") then
      utils.setVirtualText(
        bufnr,
        config.namespace.ns_default_exports,
        row,
        col,
        "Default export found",
        config.signs.error.icon,
        config.signs.error.highlightGroup
      )
    end
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_default_exports, 0, -1)
end

return M
