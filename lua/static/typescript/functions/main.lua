local settings = require("static.typescript.functions.settings")
local utils = require("static.typescript.functions.utils")

local M = {}
local api = vim.api
local ts = vim.treesitter
local config = settings.config

-- Clear all virtual text
function M.clear_hints()
  local bufnr = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(bufnr, settings.ns_id, 0, -1)
end

-- Main function to update hints
function M.update_hints()
  if not config.enabled then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local filetype = api.nvim_buf_get_option(bufnr, "filetype")

  -- Only process TypeScript/JavaScript files
  if not vim.tbl_contains({ "typescript", "javascript", "typescriptreact", "javascriptreact" }, filetype) then
    return
  end

  -- Clear existing virtual text
  M.clear_hints()

  -- Get the syntax tree
  local parser = ts.get_parser(bufnr)
  if not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local root = tree:root()

  -- Get visible range
  local win = api.nvim_get_current_win()
  local start_row = math.max(
    0,
    api.nvim_win_call(win, function()
      return vim.fn.line("w0") - 1
    end)
  )
  local end_row = api.nvim_win_call(win, function()
    return vim.fn.line("w$") - 1
  end)

  -- Queries
  local function_query_string = [[
    (arrow_function) @function
    (method_definition) @function
    (function_expression) @function
    (function_declaration) @function
  ]]
  local function_query = ts.query.parse("typescript", function_query_string)

  local return_query_string = [[
    (return_statement) @return
  ]]
  local return_query = ts.query.parse("typescript", return_query_string)

  for _, node in function_query:iter_captures(root, bufnr, start_row, end_row + 1) do
    local start_row_node, _, end_row_node, _ = node:range()
    local line_count = end_row_node - start_row_node + 1

    -- Show function end (why are these functions so long? :D)
    if config.show_function_ends and line_count >= config.min_lines then
      local func_name = utils.get_function_name(node)
      local virtual_text = string.format("end of %s", func_name)

      api.nvim_buf_set_extmark(bufnr, settings.ns_id, end_row_node, -1, {
        virt_text = { { virtual_text, config.virtual_text_color } },
        virt_text_pos = "eol",
      })
    end

    -- Show early and final exits (branching)
    if config.show_early_exits and line_count >= 8 then
      for _, return_node in return_query:iter_captures(node, bufnr, 0, -1) do
        local return_row = return_node:end_() + 1
        local node_end = node:end_()

        if return_row < node_end then
          local func_name = utils.get_function_name(node)
          local virtual_text = string.format("early exit", func_name)

          api.nvim_buf_set_extmark(bufnr, settings.ns_id, return_row - 1, -1, {
            virt_text = { { virtual_text, config.virtual_text_color } },
            virt_text_pos = "eol",
          })
        elseif return_row == node_end then
          local virtual_text = "final exit"

          api.nvim_buf_set_extmark(bufnr, settings.ns_id, return_row - 1, -1, {
            virt_text = { { virtual_text, config.virtual_text_color } },
            virt_text_pos = "eol",
          })
        end
      end
    end
  end -- end for

  -- Show parameter hints
  -- if config.show_param_hints then
  --   local params = utils.get_param_names(node)
  --   if #params > 0 then
  --     local body = node:field("body")[1]
  --     if body then
  --       for _, param in ipairs(params) do
  --         local usages = utils.find_identifier_usages(body, param.name)
  --         for _, usage in ipairs(usages) do
  --           -- Only show hint if it's in visible range and not the parameter declaration itself
  --           if usage.row >= start_row and usage.row <= end_row then
  --             local param_start_row, param_start_col = param.node:start()
  --             if not (usage.row == param_start_row and usage.col == param_start_col) then
  --               local virtual_text = string.format("← param: %s", param.name)

  --               api.nvim_buf_set_extmark(bufnr, settings.ns_id, usage.row, usage.col, {
  --                 virt_text = { { virtual_text, config.virtual_text_color } },
  --                 virt_text_pos = "eol",
  --               })
  --             end
  --           end
  --         end
  --       end
  --     end
  --   end
  -- end
end

return M
