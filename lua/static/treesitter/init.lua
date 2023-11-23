local M                     = {}
local fold                  = require('static.treesitter.fold')
local regions               = require('static.treesitter.regions')
local early_exits           = require('static.treesitter.early_exits')
local named_imports         = require('static.treesitter.named_imports')
local default_exports       = require('static.treesitter.default_exports')

function M.fold_imports()
  fold.imports()
end

function M.region()
  regions.main()
end

function M.early_exits() return early_exits.show() end

function M.early_exits_clear() return early_exits.clear() end

function M.named_imports() return named_imports.show() end

function M.named_imports_clear() return named_imports.clear() end

function M.default_exports() return default_exports.show() end

function M.default_exports_clear() return default_exports.clear() end

return M
