local utils = require('static.utils')
local config = require('static.config')

local M = {}

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  if not utils.enabled_when_supprted_filetype(config.supported_filetypes, bufnr) then
    return utils.noop
  end

  local exports_query = [[ (export_statement) @captures ]]
  local _, parsed, root = utils.query_buffer(bufnr, exports_query)
  if not parsed then
    return utils.noop
  end
  for _, match in parsed:iter_matches(root, bufnr) do
    for _, node in pairs(match) do
      local text = vim.treesitter.get_node_text(node, bufnr)
      local line, col, _ = node:start()

      if string.match(text, "export default") then
        utils.setVirtualText(
          config.namespace.ns_default_exports,
          line,
          col,
          "Default export found",
          config.signs.error.text,
          config.signs.error.highlightGroup
        )
      end
    end
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_default_exports, 0, -1)
end

return M
