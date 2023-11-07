local utils = require('static.utils')
local config = require('static.config')

local M = {}

local import_query = [[ (import_statement) @captures ]]

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  if not utils.enabled_when_supprted_filetype(config.supported_filetypes, bufnr) then
    return utils.noop
  end

  local _, parsed, root = utils.query_buffer(bufnr, import_query)
  if not parsed then
    return utils.noop
  end
  for _, match in parsed:iter_matches(root, bufnr) do
    for _, node in pairs(match) do
      local text = vim.treesitter.get_node_text(node, bufnr)
      local line, col, _ = node:start()

      if string.match(text, "* as") then
        utils.setVirtualText(
          config.namespace.ns_imports,
          line,
          col,
          "Star import found",
          config.signs.error.text,
          config.signs.error.highlightGroup
        )
      elseif not string.match(text, "{") then
        utils.setVirtualText(
          config.namespace.ns_imports,
          line,
          col,
          "Named import found",
          config.signs.error.text,
          config.signs.error.highlightGroup
        )
      end
    end
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_imports, 0, -1)
end

return M
