require("static.treesitter.typescript.generate_tests")

local utils = require('static.utils')
local config = require('static.config')
local ts = require('static.treesitter')

local M = {}

M.defaults = {
  folding = {
    go = "(import_declaration) @imports",

    javascript = "(import_statement) @imports",
    typescript = "(import_statement) @imports",
  }
}

function M.setup(opts)
  opts = opts or M.defaults

  if not utils.enabled_when_supprted_filetype(config.supported_filetypes, bufnr) then
    return
  end

  utils.register_ts_autocmd('root', function()
    ts.early_exits_clear()
    ts.early_exits()

    ts.named_imports_clear()
    ts.named_imports()

    ts.default_exports_clear()
    ts.default_exports()
  end)
end

return M
