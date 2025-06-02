require("static.treesitter.typescript")

local M = {}
local default_exports = require("static.treesitter.default_exports")
local fold = require("static.treesitter.fold")
local named_imports = require("static.treesitter.named_imports")
local regions = require("static.treesitter.regions")

function M.fold_imports()
  fold.imports()
end

function M.region()
  regions.main()
end

function M.named_imports()
  return named_imports.show()
end

function M.named_imports_clear()
  return named_imports.clear()
end

function M.default_exports()
  return default_exports.show()
end

function M.default_exports_clear()
  return default_exports.clear()
end

return M
