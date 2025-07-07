local logic = require("static.typescript.functions.main")
local settings = require("static.typescript.functions.settings")

local M = {}
local timer = nil
local api = vim.api
local config = settings.config

function M.setup(opts)
  config = vim.tbl_deep_extend("force", settings.config, opts or {})

  -- Create autocmds
  local group = api.nvim_create_augroup("TSFunctionHints", { clear = true })

  api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter", "WinScrolled" }, {
    group = group,
    pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
    callback = function()
      if not config.enabled then
        return
      end

      if timer then
        timer:stop()
      end

      timer = vim.defer_fn(function()
        logic.update_hints()
        logic.render_function_hints()
      end, config.debounce_ms)
    end,
  })

  api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      logic.clear_hints()
    end,
  })
end

function M.toggle()
  config.enabled = not config.enabled
  if config.enabled then
    logic.update_hints()
    print("TS Function Hints: Enabled")
  else
    logic.clear_hints()
    print("TS Function Hints: Disabled")
  end
end

function M.enable()
  config.enabled = true
  logic.update_hints()
  logic.setup_function_folding_keymaps()
  print("TS Function Hints: Enabled")
end

function M.disable()
  config.enabled = false
  logic.clear_hints()
  print("TS Function Hints: Disabled")
end

function M.get_config()
  return vim.deepcopy(config)
end

return M
