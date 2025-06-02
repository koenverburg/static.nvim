local config = require("static.config")
local utils = require("static.utils")

local M = {}
local api = vim.api
local ts = vim.treesitter

local query_string = [[
  (export_statement) @captures
]]

function M.show()
  local bufnr = api.nvim_get_current_buf()
  local filetype = api.nvim_buf_get_option(bufnr, "filetype")

  -- Only process TypeScript/JavaScript files
  if not vim.tbl_contains({ "typescript", "javascript", "typescriptreact", "javascriptreact" }, filetype) then
    return
  end

  local parser = vim.treesitter.get_parser(bufnr)

  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse("typescript", query_string)

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local row, col = node:range()
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

    if line:match("export%s+default") then
      -- api.nvim_buf_set_extmark(bufnr, settings.ns_id, return_row-1, -1, {
      --     virt_text = { { virtual_text, config.virtual_text_color } },
      --     virt_text_pos = "eol",
      --   })

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
