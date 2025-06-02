-- TODO Refactor this file
-- zE will remove markers
-- za will toggle folds
local utils = require("static.utils")

local M = {}
local js = "(import_statement) @imports"

local queries = {
  go = "(import_declaration) @imports",

  tsx = js,
  javascript = js,
  typescript = js,
}

-- local function foldGo(matches)
--   for _, match, _ in matches do
--     local start_line = match[1]:start() + 1
--     local end_line = match[1]:end_() + 1

--     vim.cmd(string.format("%s,%s fold", start_line, end_line))
--   end
-- end

local function foldTypescript(matches)
  local index = 1
  local start_fold_line = 0
  local end_fold_line = 0

  for _, match, _ in matches do
    local start_line = match[1]:start()
    local end_line = match[1]:end_()

    if index == 1 then
      start_fold_line = start_line
    end

    if end_line > end_fold_line then
      end_fold_line = end_line
    end

    index = index + 1
  end

  vim.cmd(string.format("%s,%s fold", start_fold_line, end_fold_line + 1))
end

function M._get_language_query(lang)
  local current_query = queries[lang]

  if not current_query then
    vim.notify("[static] Error: queries for this languages are not implemented")
    return nil
  end

  return current_query
end

function M.imports()
  vim.cmd([[ set foldmethod=manual ]])

  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(bufnr, "ft")
  local lang = require("nvim-treesitter.parsers").ft_to_lang(filetype)

  local query = M._get_language_query(lang)
  if not query then
    return
  end

  local matches = utils.get_query_matches(bufnr, lang, query)
  if matches == nil then
    return
  end

  if lang == "typescript" or lang == "tsx" then
    foldTypescript(matches)
  end

  -- if lang == "go" then
  --   foldGo(matches)
  -- end
end

return M
