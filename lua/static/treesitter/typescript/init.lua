-- TypeScript AST Analysis Functions for Neovim
local parsers = require("nvim-treesitter.parsers")
local utils = require("static.treesitter.typescript.utils")

local M = {}

-- Find all any types in current buffer
function M.find_any_types()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local any_types = {}
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (type_annotation
      (predefined_type) @type
      (#eq? @type "any"))
  ]]
  )

  for _, node in query:iter_captures(root, 0) do
    local start_row, start_col = node:start()
    table.insert(any_types, {
      line = start_row + 1,
      col = start_col + 1,
      text = vim.treesitter.get_node_text(node, 0),
    })
  end

  -- Show results in quickfix
  local qf_items = {}
  for _, item in ipairs(any_types) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      col = item.col,
      text = "Found 'any' type usage",
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
  print("Found " .. #any_types .. " 'any' type usages")
end

-- Helper function to calculate cyclomatic complexity
local function calculate_complexity(node)
  local complexity = 1 -- base complexity
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (if_statement) @decision
    (while_statement) @decision
    (for_statement) @decision
    (for_in_statement) @decision
    (switch_statement) @decision
    (catch_clause) @decision
    (conditional_expression) @decision
  ]]
  )

  for _ in query:iter_captures(node, 0) do
    complexity = complexity + 1
  end

  return complexity
end

-- Analyze function complexity (nested blocks)
function M.analyze_function_complexity()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local complex_functions = {}
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (function_declaration
      name: (identifier) @func_name
      body: (statement_block) @func_body)
    (method_definition
      name: (property_identifier) @method_name
      value: (function
        body: (statement_block) @method_body))
  ]]
  )

  for id, node, _ in query:iter_captures(root, 0) do
    local capture_name = query.captures[id]
    if capture_name == "func_body" or capture_name == "method_body" then
      local complexity = calculate_complexity(node)
      if complexity > 5 then -- threshold
        local start_row = node:start()
        table.insert(complex_functions, {
          line = start_row + 1,
          complexity = complexity,
        })
      end
    end
  end

  local qf_items = {}
  for _, item in ipairs(complex_functions) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = "High complexity function (score: " .. item.complexity .. ")",
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
end

-- Find unused imports
function M.find_unused_imports()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Get all imports
  local imports = {}
  local import_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (import_statement
      (import_clause
        (named_imports
          (import_specifier
            name: (identifier) @import_name))))
  ]]
  )

  for _, node in import_query:iter_captures(root, 0) do
    local import_name = vim.treesitter.get_node_text(node, 0)
    imports[import_name] = {
      node = node,
      used = false,
    }
  end

  -- Check usage
  local usage_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (identifier) @usage
  ]]
  )

  for _, node in usage_query:iter_captures(root, 0) do
    local name = vim.treesitter.get_node_text(node, 0)
    if imports[name] and node ~= imports[name].node then
      imports[name].used = true
    end
  end

  -- Report unused
  local unused = {}
  for name, data in pairs(imports) do
    if not data.used then
      local start_row = data.node:start()
      table.insert(unused, {
        name = name,
        line = start_row + 1,
      })
    end
  end

  local qf_items = {}
  for _, item in ipairs(unused) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = "Unused import: " .. item.name,
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
  print("Found " .. #unused .. " unused imports")
end

-- Find functions with too many parameters
function M.find_parameter_heavy_functions()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local heavy_functions = {}
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (function_declaration
      name: (identifier) @func_name
      parameters: (formal_parameters) @params)
    (method_definition
      name: (property_identifier) @method_name
      value: (function
        parameters: (formal_parameters) @params))
  ]]
  )

  for id, node in query:iter_captures(root, 0) do
    local capture_name = query.captures[id]
    if capture_name == "params" then
      local param_count = node:named_child_count()
      if param_count > 4 then -- threshold
        local start_row = node:start()
        table.insert(heavy_functions, {
          line = start_row + 1,
          count = param_count,
        })
      end
    end
  end

  local qf_items = {}
  for _, item in ipairs(heavy_functions) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = "Function with " .. item.count .. " parameters (consider refactoring)",
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
end

-- Find missing error handling in async functions
function M.find_unhandled_promises()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local unhandled = {}
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (call_expression
      function: (member_expression
        property: (property_identifier) @method)
      (#match? @method "^(then|catch)$")) @promise_call
    (await_expression) @await_expr
  ]]
  )

  -- This is a simplified version - you'd want to check if these are inside try-catch
  for id, node in query:iter_captures(root, 0) do
    local start_row = node:start()
    table.insert(unhandled, {
      line = start_row + 1,
      type = query.captures[id],
    })
  end

  print("Found " .. #unhandled .. " async operations to review for error handling")
end

-- Find console.log statements (for cleanup)
function M.find_console_logs()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local console_logs = {}
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (call_expression
      function: (member_expression
        object: (identifier) @console (#eq? @console "console")
        property: (property_identifier) @method (#eq? @method "log"))) @call
  ]]
  )

  for id, node in query:iter_captures(root, 0) do
    if query.captures[id] == "call" then
      local start_row = node:start()
      table.insert(console_logs, {
        line = start_row + 1,
      })
    end
  end

  local qf_items = {}
  for _, item in ipairs(console_logs) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = "console.log found - consider removing",
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
  print("Found " .. #console_logs .. " console.log statements")
end

-- Check if JSDoc already exists above the function
local function has_existing_jsdoc(func_start_row)
  local lines_above = vim.api.nvim_buf_get_lines(0, math.max(0, func_start_row - 10), func_start_row, false)

  for i = #lines_above, 1, -1 do
    local line = lines_above[i]:match("^%s*(.-)%s*$") -- trim whitespace
    if line == "" then
    -- Skip empty lines
    elseif line:match("^%*/$") then
      return true -- Found end of JSDoc comment
    elseif not line:match("^[/%*%s]*$") then
      break -- Found non-comment content
    end
  end

  return false
end

-- Remove existing JSDoc comment
local function remove_existing_jsdoc(func_start_row)
  local start_line = nil
  local end_line = func_start_row - 1

  -- Find the start of JSDoc comment
  for i = func_start_row - 1, math.max(0, func_start_row - 20), -1 do
    local line = vim.api.nvim_buf_get_lines(0, i, i + 1, false)[1] or ""
    line = line:match("^%s*(.-)%s*$") -- trim whitespace

    if line:match("^/%*%*") then
      start_line = i
      break
    elseif line ~= "" and not line:match("^[%*%s]*") then
      break -- Found non-comment content
    end
  end

  if start_line then
    vim.api.nvim_buf_set_lines(0, start_line, end_line + 1, false, {})
  end
end

-- Update existing JSDoc (preserves custom descriptions)
local function update_existing_jsdoc(func_start_row, new_jsdoc_lines)
  remove_existing_jsdoc(func_start_row)
  -- Re-get the function node as line numbers may have changed
  local cursor = vim.api.nvim_win_get_cursor(0)
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()
  local func_node = utils.find_function_at_cursor(root, cursor[1] - 1)

  if func_node then
    local start_row, _ = func_node:start()
    vim.api.nvim_buf_set_lines(0, start_row, start_row, false, new_jsdoc_lines)
  end
end

-- Insert JSDoc comment above function
local function insert_jsdoc(func_node, jsdoc_lines)
  local start_row, _ = func_node:start()

  -- Check if JSDoc already exists
  if has_existing_jsdoc(start_row) then
    local choice = vim.fn.confirm("JSDoc already exists. Replace it?", "&Yes\n&No\n&Update", 2)
    if choice == 2 then -- No
      return
    elseif choice == 3 then -- Update
      update_existing_jsdoc(start_row, jsdoc_lines)
      return
    else -- Yes, continue to replace
      remove_existing_jsdoc(start_row)
    end
  end

  -- Insert the JSDoc comment
  vim.api.nvim_buf_set_lines(0, start_row, start_row, false, jsdoc_lines)
  print("JSDoc generated successfully!")
end

-- Generate JSDoc comment from function node
local function generate_jsdoc_comment(func_node)
  local func_info = utils.extract_function_info(func_node)
  if not func_info then
    return nil
  end

  local lines = { "/**" }

  -- Description
  table.insert(lines, " * " .. (func_info.description or "TODO: Add description"))

  -- Parameters
  if #func_info.params > 0 then
    table.insert(lines, " *")
    for _, param in ipairs(func_info.params) do
      local param_type = param.type or "any"
      local param_desc = param.optional and "(optional) " or ""
      table.insert(
        lines,
        " * @param {" .. param_type .. "} " .. param.name .. " " .. param_desc .. "TODO: Add parameter description"
      )
    end
  end

  -- Return type
  if func_info.return_type and func_info.return_type ~= "void" then
    table.insert(lines, " * @returns {" .. func_info.return_type .. "} TODO: Add return description")
  end

  -- Async function
  if func_info.is_async then
    table.insert(lines, " * @async")
  end

  -- Throws (if we detect throw statements)
  if func_info.throws then
    table.insert(lines, " * @throws {Error} TODO: Document error conditions")
  end

  table.insert(lines, " */")

  return lines
end

-- Generate JSDoc for function at cursor
function M.generate_jsdoc()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1 -- Convert to 0-based

  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Find the function node that contains the cursor
  local function_node = utils.find_function_at_cursor(root, cursor_row)
  if not function_node then
    print("No function found at cursor position")
    return
  end

  local jsdoc = generate_jsdoc_comment(function_node)
  if jsdoc then
    insert_jsdoc(function_node, jsdoc)
  end
end

-- Generate JSDoc for all functions in buffer
function M.generate_all_jsdocs()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (function_declaration) @func
    (method_definition) @func
  ]]
  )

  local functions = {}
  for _, node in query:iter_captures(root, 0) do
    local start_row = node:start()
    if not has_existing_jsdoc(start_row) then
      table.insert(functions, { node = node, row = start_row })
    end
  end

  -- Sort by line number (bottom to top to avoid line number shifts)
  table.sort(functions, function(a, b)
    return a.row > b.row
  end)

  local count = 0
  for _, func_info in ipairs(functions) do
    local jsdoc = generate_jsdoc_comment(func_info.node)
    if jsdoc then
      vim.api.nvim_buf_set_lines(0, func_info.row, func_info.row, false, jsdoc)
      count = count + 1
    end
  end

  print("Generated JSDoc for " .. count .. " functions")
end

-- Find performance anti-patterns
function M.find_performance_issues()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local performance_issues = {}

  -- Object creation in loops
  local loop_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (for_statement
      body: (statement_block) @loop_body)
    (while_statement
      body: (statement_block) @loop_body)
    (for_in_statement
      body: (statement_block) @loop_body)
  ]]
  )

  for _, loop_body in loop_query:iter_captures(root, 0) do
    -- Check for object/array creation inside loops
    local object_query = vim.treesitter.query.parse(
      "typescript",
      [[
      (object) @obj
      (array) @arr
      (new_expression) @new_obj
      (call_expression
        function: (member_expression
          property: (property_identifier) @method)
        (#match? @method "^(map|filter|reduce|forEach)$")) @array_method
    ]]
    )

    for obj_id, obj_node in object_query:iter_captures(loop_body, 0) do
      local start_row = obj_node:start()
      local issue_type = object_query.captures[obj_id]
      local message = "Object/Array creation in loop"
      if issue_type == "array_method" then
        message = "Array method in loop (consider caching)"
      elseif issue_type == "new_obj" then
        message = "Object instantiation in loop"
      end

      table.insert(performance_issues, {
        line = start_row + 1,
        message = message,
      })
    end
  end

  -- Inefficient string concatenation
  local concat_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (assignment_expression
      left: (identifier) @var
      right: (binary_expression
        left: (identifier) @left_var
        operator: "+"
        right: (_) @right_expr)
      (#eq? @var @left_var)) @string_concat
  ]]
  )

  for id, node in concat_query:iter_captures(root, 0) do
    if concat_query.captures[id] == "string_concat" then
      local start_row = node:start()
      table.insert(performance_issues, {
        line = start_row + 1,
        message = "String concatenation in loop - consider using array.join()",
      })
    end
  end

  -- DOM queries in loops or frequent calls
  local dom_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (call_expression
      function: (member_expression
        object: (identifier) @document (#eq? @document "document")
        property: (property_identifier) @method
        (#match? @method "^(querySelector|getElementById|getElementsBy)"))
      ) @dom_query
  ]]
  )

  for _, node in dom_query:iter_captures(root, 0) do
    -- Check if it's inside a loop
    local parent = node:parent()
    while parent do
      if parent:type():match("for_") or parent:type() == "while_statement" then
        local start_row = node:start()
        table.insert(performance_issues, {
          line = start_row + 1,
          message = "DOM query in loop - cache the result",
        })
        break
      end
      parent = parent:parent()
    end
  end

  -- Regular expression creation in loops
  local regex_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (new_expression
      constructor: (identifier) @constructor (#eq? @constructor "RegExp")) @regex_new
    (regex) @regex_literal
  ]]
  )

  for _, node in regex_query:iter_captures(root, 0) do
    local parent = node:parent()
    while parent do
      if parent:type():match("for_") or parent:type() == "while_statement" then
        local start_row = node:start()
        table.insert(performance_issues, {
          line = start_row + 1,
          message = "RegExp creation in loop - move outside loop",
        })
        break
      end
      parent = parent:parent()
    end
  end

  local qf_items = {}
  for _, item in ipairs(performance_issues) do
    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = "Performance: " .. item.message,
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
  print("Found " .. #performance_issues .. " potential performance issues")
end

-- Find dead code (unused functions/variables in current buffer)
function M.find_dead_code()
  local parser = parsers.get_parser(0, "typescript")
  local tree = parser:parse()[1]
  local root = tree:root()

  local declarations = {}
  local usages = {}
  local dead_code = {}

  -- Collect function declarations
  local func_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (function_declaration
      name: (identifier) @func_name) @func_decl
    (variable_declarator
      name: (identifier) @var_name
      value: (arrow_function)) @arrow_func
    (variable_declarator
      name: (identifier) @var_name) @var_decl
    (class_declaration
      name: (type_identifier) @class_name) @class_decl
  ]]
  )

  for id, node in func_query:iter_captures(root, 0) do
    local capture_name = func_query.captures[id]
    if capture_name:match("_name$") then
      local name = vim.treesitter.get_node_text(node, 0)
      local start_row = node:start()
      declarations[name] = {
        node = node,
        line = start_row + 1,
        type = capture_name:gsub("_name$", ""),
        used = false,
      }
    end
  end

  -- Collect all identifier usages
  local usage_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (identifier) @usage
    (type_identifier) @type_usage
  ]]
  )

  for _, node in usage_query:iter_captures(root, 0) do
    local name = vim.treesitter.get_node_text(node, 0)
    if not usages[name] then
      usages[name] = {}
    end
    table.insert(usages[name], node)
  end

  -- Check which declarations are actually used
  for name, decl_info in pairs(declarations) do
    if usages[name] then
      -- Check if any usage is not the declaration itself
      for _, usage_node in ipairs(usages[name]) do
        if usage_node ~= decl_info.node then
          decl_info.used = true
          break
        end
      end
    end

    -- Special handling for exports - they're considered used
    local parent = decl_info.node:parent()
    while parent do
      if parent:type() == "export_statement" or parent:type() == "export_declaration" then
        decl_info.used = true
        break
      end
      parent = parent:parent()
    end

    if not decl_info.used then
      table.insert(dead_code, {
        name = name,
        line = decl_info.line,
        type = decl_info.type,
      })
    end
  end

  -- Find unreachable code (after return statements)
  local unreachable_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (return_statement) @return
    (throw_statement) @throw
  ]]
  )

  for _, node in unreachable_query:iter_captures(root, 0) do
    local parent = node:parent()
    if parent and parent:type() == "statement_block" then
      local return_index = nil
      for i = 0, parent:named_child_count() - 1 do
        if parent:named_child(i) == node then
          return_index = i
          break
        end
      end

      -- Check if there are statements after return/throw
      if return_index and return_index < parent:named_child_count() - 1 then
        local next_stmt = parent:named_child(return_index + 1)
        local start_row = next_stmt:start()
        table.insert(dead_code, {
          name = "unreachable_code",
          line = start_row + 1,
          type = "unreachable",
        })
      end
    end
  end

  local qf_items = {}
  for _, item in ipairs(dead_code) do
    local message = "Dead code: "
    if item.type == "unreachable" then
      message = "Unreachable code after return/throw"
    else
      message = message .. "unused " .. item.type .. " '" .. item.name .. "'"
    end

    table.insert(qf_items, {
      bufnr = vim.api.nvim_get_current_buf(),
      lnum = item.line,
      text = message,
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd("copen")
  print("Found " .. #dead_code .. " dead code issues")
end

-- Create commands
vim.api.nvim_create_user_command("TSFindAnyTypes", M.find_any_types, {})
vim.api.nvim_create_user_command("TSAnalyzeComplexity", M.analyze_function_complexity, {})
vim.api.nvim_create_user_command("TSFindUnusedImports", M.find_unused_imports, {})
vim.api.nvim_create_user_command("TSFindHeavyFunctions", M.find_parameter_heavy_functions, {})
vim.api.nvim_create_user_command("TSFindConsoleLogs", M.find_console_logs, {})
vim.api.nvim_create_user_command("TSCheckPromises", M.find_unhandled_promises, {})
vim.api.nvim_create_user_command("TSFindPerformanceIssues", M.find_performance_issues, {})
vim.api.nvim_create_user_command("TSFindDeadCode", M.find_dead_code, {})
vim.api.nvim_create_user_command("TSGenerateJSDoc", M.generate_jsdoc, {})
vim.api.nvim_create_user_command("TSGenerateAllJSDocs", M.generate_all_jsdocs, {})

-- Keymaps (optional)
vim.keymap.set("n", "<leader>ta", M.find_any_types, { desc = "Find any types" })
vim.keymap.set("n", "<leader>tc", M.analyze_function_complexity, { desc = "Analyze complexity" })
vim.keymap.set("n", "<leader>tu", M.find_unused_imports, { desc = "Find unused imports" })
vim.keymap.set("n", "<leader>tp", M.find_parameter_heavy_functions, { desc = "Find parameter-heavy functions" })
vim.keymap.set("n", "<leader>tl", M.find_console_logs, { desc = "Find console.logs" })
vim.keymap.set("n", "<leader>tf", M.find_performance_issues, { desc = "Find performance issues" })
vim.keymap.set("n", "<leader>td", M.find_dead_code, { desc = "Find dead code" })
vim.keymap.set("n", "<leader>tj", M.generate_jsdoc, { desc = "Generate JSDoc for function at cursor" })
vim.keymap.set("n", "<leader>tJ", M.generate_all_jsdocs, { desc = "Generate JSDoc for all functions" })

return M
