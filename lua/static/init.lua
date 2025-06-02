-- require("static.treesitter.typescript.generate_tests")
local ts = require("static.treesitter")
local typescriptFunctions = require("static.typescript.functions.init")
local utils = require("static.utils")

local M = {}

M.defaults = {
  folding = {
    go = "(import_declaration) @imports",

    javascript = "(import_statement) @imports",
    typescript = "(import_statement) @imports",
  },
}

function M.setup(opts)
  opts = opts or M.defaults

  typescriptFunctions.setup()
  typescriptFunctions.enable()

  utils.register_ts_autocmd("root", function()
    ts.named_imports_clear()
    ts.named_imports()

    ts.default_exports_clear()
    ts.default_exports()
  end)
end

return M
