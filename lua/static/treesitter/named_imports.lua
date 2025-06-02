local config = require("static.config")
local utils = require("static.utils")

local M = {}

local query_string = [[
  ;; default-only
  (import_clause
    (identifier) @default_import
  )

  ;; default + named
  (import_clause
    (identifier) @default_import
    (named_imports
      (import_specifier
        name: (identifier) @imported_name
        alias: (identifier)? @imported_alias
      )
    )
  )

  ;; named-only
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @imported_name
        alias: (identifier)? @imported_alias
      )
    )
  )

  ;; namespace import
  (import_clause
    (namespace_import
      (identifier) @namespace_import
    )
  )
]]

function M.show()
  local bufnr = vim.api.nvim_get_current_buf()

  local lang = vim.bo[bufnr].filetype
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end
  local root = tree:root()
  local query = vim.treesitter.query.parse(lang, query_string)

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local capture = query.captures[id]
    local text = vim.treesitter.get_node_text(node, bufnr)
    local line, col = node:range()

    local label = ({
      default_import = "default import found",
      -- imported_name = "← named import",
      -- imported_alias = "← alias",
    })[capture]

    local hl = ({
      default_import = "WarningMsg",
      -- imported_name = "WarningMsg",
      -- imported_alias = "MoreMsg",
    })[capture]

    if label and hl then
      utils.setVirtualText(
        bufnr,
        config.namespace.ns_imports,
        line,
        col,
        label,
        config.signs.error.icon,
        config.signs.error.highlightGroup
      )
    end
  end
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(0, config.namespace.ns_imports, 0, -1)
end

return M
