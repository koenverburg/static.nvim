local M = {}

function M.noop() end

function M.register_autocmd(name, callback)
  local augroup = "static-" .. name
  local events = {
    -- "LspAttach",
    "FileType",
    "BufEnter",
    -- "BufWritePost",
    -- "DiagnosticChanged",
  }
  vim.api.nvim_create_augroup(augroup, {})
  vim.api.nvim_create_autocmd(events, {
    group = augroup,
    callback = callback,
    pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  })
end

function M.register_ts_autocmd(name, callback)
  local augroup = "static-ts-" .. name
  local events = {
    -- "FileType",
    "BufEnter",
    "BufWritePost",
    -- "DiagnosticChanged",
  }
  vim.api.nvim_create_augroup(augroup, {})
  vim.api.nvim_create_autocmd(events, {
    group = augroup,
    callback = callback,
    pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
  })
end

function M.enabled_when_supprted_filetype(supported_filetypes, bufnr)
  if not supported_filetypes or not bufnr then
    print("No supported filetypes or bufnr")
    return false
  end

  local filetype = vim.bo.filetype
  -- local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  if M.contains(supported_filetypes, filetype) then
    return true
  end

  return false
end

function M.get_query_matches(bufnr, lang, query)
  local parser = vim.treesitter.get_parser(bufnr, lang)

  if not parser then
    return nil
  end

  local ast = parser:parse()
  local root = ast[1]:root()

  local parsed = vim.treesitter.query.parse(lang, query)
  local results = parsed:iter_matches(root, bufnr)

  return results
end

function M.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function M.is_empty(v)
  return v == nil or v == ""
end

function M.setVirtualText(bufnr, ns, line, col, text, prefix, color)
  local virtualText = string.format("%s", text)

  if not M.is_empty(prefix) then
    virtualText = string.format("%s %s", prefix, text)
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
    virt_text = { { virtualText, color or "Comment" } },
  })
end

local function createIndent(tbl, length)
  for i = 1, length do
    tbl[i] = { " ", 0 }
  end
  return tbl
end

function M.setVirtualTextAbove(ns, line, col, text, prefix, color)
  col = col or 0
  color = color or "Comment"

  text = string.format("%s", text)

  if not M.is_empty(prefix) then
    text = string.format("%s %s", prefix, text)
  end

  local tbl = {}
  createIndent(tbl, col)

  table.insert(tbl, { text, color })

  vim.api.nvim_buf_set_extmark(0, ns, line, col, {
    virt_lines_above = true,
    virt_lines = { tbl },
  })
end

function M.query_buffer(bufnr, queries)
  local filetype = vim.bo.filetype
  local lang = require("nvim-treesitter.parsers").ft_to_lang(filetype)

  local parser = vim.treesitter.get_parser(bufnr, lang)
  if not parser then
    return nil
  end

  local tree = parser:parse()
  local root = tree[1]:root()
  local parsed = vim.treesitter.query.parse(lang, queries)

  return parser, parsed, root
end

return M
