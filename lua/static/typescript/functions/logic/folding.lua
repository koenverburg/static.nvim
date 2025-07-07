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

-- Add this function to your M table in the existing file
function M.fold_current_function()
  local bufnr = api.nvim_get_current_buf()
  local filetype = api.nvim_buf_get_option(bufnr, "filetype")

  -- Only process TypeScript/JavaScript files
  if not vim.tbl_contains({ "typescript", "javascript", "typescriptreact", "javascriptreact" }, filetype) then
    return
  end

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

  -- Get current cursor position
  local cursor = api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-based indexing
  local cursor_col = cursor[2]

  -- Function query
  local function_query_string = [[
    (arrow_function) @function
    (method_definition) @function
    (function_expression) @function
    (function_declaration) @function
  ]]
  local function_query = ts.query.parse("typescript", function_query_string)

  -- Find the function that contains the cursor
  local target_function = nil
  local smallest_range = math.huge

  for _, node in function_query:iter_captures(root, bufnr, 0, -1) do
    local start_row, start_col, end_row, end_col = node:range()

    -- Check if cursor is within this function
    if cursor_row >= start_row and cursor_row <= end_row then
      if cursor_row == start_row and cursor_col < start_col then
        -- Cursor is before the function on the same line
      elseif cursor_row == end_row and cursor_col > end_col then
        -- Cursor is after the function on the same line
      else
        -- Cursor is within the function
        local range_size = (end_row - start_row) * 1000 + (end_col - start_col)
        if range_size < smallest_range then
          smallest_range = range_size
          target_function = node
        end
      end
    end
  end

  if target_function then
    local start_row, _, end_row, _ = target_function:range()

    -- Convert to 1-based indexing for vim commands
    local fold_start = start_row + 1
    local fold_end = end_row + 1

    -- Save current cursor position
    local cursor_pos = api.nvim_win_get_cursor(0)

    -- Move cursor to start of function and select the range
    api.nvim_win_set_cursor(0, { fold_start, 0 })

    -- Enter visual line mode and select the entire function
    vim.cmd("normal! V")
    api.nvim_win_set_cursor(0, { fold_end, 0 })

    -- Create the fold
    vim.cmd("normal! zf")

    -- Restore cursor position (or move to folded line)
    api.nvim_win_set_cursor(0, { fold_start, 0 })

    -- Optional: Print confirmation
    local func_name = utils.get_function_name(target_function)
    print(string.format("Folded function: %s (lines %d-%d)", func_name, fold_start, fold_end))
  else
    print("No function found at cursor position")
  end
end

-- Add keymap setup function
function M.setup_function_folding_keymaps()
  -- Set up the keymap for folding current function
  -- You can change '<leader>zf' to whatever key combination you prefer
  vim.keymap.set("n", "<leader>zf", function()
    M.fold_current_function()
  end, {
    desc = "Fold current function",
    silent = true,
  })

  -- Alternative keymaps you might want:
  vim.keymap.set("n", "zf", M.fold_current_function, { desc = "Fold current function" })
  vim.keymap.set("n", "<C-f>", M.fold_current_function, { desc = "Fold current function" })
end
