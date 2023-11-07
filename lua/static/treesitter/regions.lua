local utils = require('static.utils')
local config = require('static.config')

local M = {}

-- #region queries
local queries = {
  lua             = "(comment) @captures",
  javascript      = "(comment) @captures",
  typescript      = "(comment) @captures",
  reactjavascript = "(comment) @captures",
  reacttypescript = "(comment) @captures",
}
-- #endregion

function M.main()
  local bufnr = vim.api.nvim_get_current_buf()
  if not utils.enabled_when_supprted_filetype(config.supported_filetypes, bufnr) then
    return
  end

  local _, parsed, root = utils.query_buffer(bufnr, "(comment) @captures")
  if not parsed then
    return
  end

  local nodes_of_interest = {}
  for _, match in parsed:iter_matches(root, bufnr) do
    for _, node in pairs(match) do
      local text = vim.treesitter.get_node_text(node, bufnr)

      if string.find(text, '#region') then
        table.insert(nodes_of_interest, node)
      end

      if string.find(text, '#endregion') then
        table.insert(nodes_of_interest, node)
      end
    end
  end

  for i = 1, #nodes_of_interest, 2 do
    local pair = { nodes_of_interest[i], nodes_of_interest[i + 1] }

    local from = pair[1]
    local to = pair[2]

    vim.cmd(string.format("%s,%s fold", from:start() + 1, to:start() + 1))
  end
end

return M
