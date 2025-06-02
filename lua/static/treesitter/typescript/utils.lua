local utils = {}

utils.infer_return_type = function(func_node)
  local return_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (return_statement
      (identifier) @return_value)
    (return_statement
      (string) @string_return)
    (return_statement
      (number) @number_return)
    (return_statement
      (true) @boolean_return)
    (return_statement
      (false) @boolean_return)
    (return_statement
      (object) @object_return)
    (return_statement
      (array) @array_return)
  ]]
  )

  for id, _ in return_query:iter_captures(func_node, 0) do
    local capture_name = return_query.captures[id]
    if capture_name == "string_return" then
      return "string"
    elseif capture_name == "number_return" then
      return "number"
    elseif capture_name == "boolean_return" then
      return "boolean"
    elseif capture_name == "object_return" then
      return "Object"
    elseif capture_name == "array_return" then
      return "Array"
    end
  end

  return "void"
end

-- Helper functions for test generation
utils.get_sample_value_for_type = function(type_str)
  local type_lower = (type_str or "any"):lower()

  if type_lower:match("string") then
    return { value = "'test string'" }
  elseif type_lower:match("number") then
    return { value = "42" }
  elseif type_lower:match("boolean") then
    return { value = "true" }
  elseif type_lower:match("array") or type_lower:match("%[%]") then
    return { value = "[1, 2, 3]" }
  elseif type_lower:match("object") or type_lower:match("{") then
    return { value = "{ key: 'value' }" }
  elseif type_lower:match("function") then
    return { value = "jest.fn()" }
  else
    return { value = "{}" }
  end
end

utils.get_expected_result_for_type = function(type_str)
  local type_lower = (type_str or "any"):lower()

  if type_lower:match("string") then
    return ".toEqual(expect.any(String))"
  elseif type_lower:match("number") then
    return ".toEqual(expect.any(Number))"
  elseif type_lower:match("boolean") then
    return ".toEqual(expect.any(Boolean))"
  elseif type_lower:match("array") then
    return ".toEqual(expect.any(Array))"
  elseif type_lower:match("promise") then
    return ".resolves.toBeDefined()"
  else
    return ".toBeDefined()"
  end
end

utils.get_type_check_for_type = function(type_str)
  local type_lower = (type_str or "any"):lower()

  if type_lower:match("string") then
    return "typeof result === 'string'"
  elseif type_lower:match("number") then
    return "typeof result === 'number'"
  elseif type_lower:match("boolean") then
    return "typeof result === 'boolean'"
  elseif type_lower:match("array") then
    return "Array.isArray(result)"
  else
    return "typeof result === 'object'"
  end
end

utils.get_edge_cases_for_type = function(type_str)
  local type_lower = (type_str or "any"):lower()
  local cases = {}

  if type_lower:match("string") then
    table.insert(cases, {
      description = "empty string",
      value = "''",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
    table.insert(cases, {
      description = "very long string",
      value = "'a'.repeat(1000)",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
  elseif type_lower:match("number") then
    table.insert(cases, {
      description = "zero",
      value = "0",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
    table.insert(cases, {
      description = "negative number",
      value = "-1",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
    table.insert(cases, {
      description = "very large number",
      value = "Number.MAX_SAFE_INTEGER",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
  elseif type_lower:match("array") then
    table.insert(cases, {
      description = "empty array",
      value = "[]",
      expectation = ".toBeDefined()",
      should_throw = false,
    })
  end

  return cases
end

utils.get_import_name_for_function = function(func_node)
  -- Extract function name for import
  local name_node = func_node:field("name")[1]
  if name_node then
    return vim.treesitter.get_node_text(name_node, 0)
  end
  return "unknownFunction"
end

utils.get_current_filename_without_ext = function()
  local filename = vim.api.nvim_buf_get_name(0)
  local basename = vim.fn.fnamemodify(filename, ":t:r")
  return basename
end

-- Enhanced extract_function_info to include function name
utils.extract_function_info = function(func_node)
  local info = {
    params = {},
    return_type = nil,
    is_async = false,
    throws = false,
    description = nil,
    name = nil,
  }

  -- Get function name
  local name_node = func_node:field("name")[1]
  if name_node then
    info.name = vim.treesitter.get_node_text(name_node, 0)
  else
    -- Handle arrow functions assigned to variables
    local parent = func_node:parent()
    if parent and parent:type() == "variable_declarator" then
      local var_name = parent:field("name")[1]
      if var_name then
        info.name = vim.treesitter.get_node_text(var_name, 0)
      end
    end
  end

  -- Check if async
  if func_node:type() == "function_declaration" then
    local parent = func_node:parent()
    if parent and vim.treesitter.get_node_text(parent, 0):match("^async%s") then
      info.is_async = true
    end
  end

  -- Extract parameters
  local params_node = func_node:field("parameters")[1]
  if params_node then
    for i = 0, params_node:named_child_count() - 1 do
      local param_node = params_node:named_child(i)
      if param_node:type() == "required_parameter" or param_node:type() == "optional_parameter" then
        local param_info = {
          name = "",
          type = "any",
          optional = param_node:type() == "optional_parameter",
        }

        -- Get parameter name
        local pattern_node = param_node:field("pattern")[1]
        if pattern_node then
          if pattern_node:type() == "identifier" then
            param_info.name = vim.treesitter.get_node_text(pattern_node, 0)
          elseif pattern_node:type() == "object_pattern" or pattern_node:type() == "array_pattern" then
            param_info.name = vim.treesitter.get_node_text(pattern_node, 0)
            param_info.type = "Object"
          end
        end

        -- Get parameter type annotation
        local type_node = param_node:field("type")[1]
        if type_node then
          param_info.type = vim.treesitter.get_node_text(type_node, 0):gsub("^:%s*", "")
        end

        table.insert(info.params, param_info)
      end
    end
  end

  -- Extract return type
  local return_type_node = func_node:field("return_type")[1]
  if return_type_node then
    info.return_type = vim.treesitter.get_node_text(return_type_node, 0):gsub("^:%s*", "")
  else
    -- Try to infer return type from return statements
    info.return_type = utils.infer_return_type(func_node)
  end

  -- Check for throw statements
  local throw_query = vim.treesitter.query.parse(
    "typescript",
    [[
    (throw_statement) @throw
  ]]
  )

  for _, _ in throw_query:iter_captures(func_node, 0) do
    info.throws = true
    break
  end

  return info
end

-- Helper function to find function node at cursor
utils.find_function_at_cursor = function(root, cursor_row)
  local query = vim.treesitter.query.parse(
    "typescript",
    [[
    (function_declaration) @func
    (method_definition) @func
    (arrow_function) @func
    (function_expression) @func
  ]]
  )

  for _, node in query:iter_captures(root, 0) do
    local start_row, _, end_row, _ = node:range()
    if cursor_row >= start_row and cursor_row <= end_row then
      return node
    end
  end

  return nil
end

return utils
