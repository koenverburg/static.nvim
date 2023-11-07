local M = {}

M.supported_filetypes = {
  -- "javascript",
  -- "javascriptreact",
  "typescript",
  "typescriptreact",
  "tsx",
}

M.signs = {
  error = { highlightGroup = "DiagnosticSignError", icon = "" },
  warn = { highlightGroup = "DiagnosticSignWarn", icon = "" },
  hint = { highlightGroup = "DiagnosticSignHint", icon = "" },
  info = { highlightGroup = "DiagnosticSignInfo", icon = "" },
}

M.namespace = {
  ns_cc = vim.api.nvim_create_namespace("static/cyclomatic_complexity"),
  ns_imports = vim.api.nvim_create_namespace("static/imports"),
  --    ns_references = vim.api.nvim_create_namespace("static/references"),
  ns_early_exit = vim.api.nvim_create_namespace("static/early-exit"),
  ns_default_exports = vim.api.nvim_create_namespace("static/default_exports")
}

return M
