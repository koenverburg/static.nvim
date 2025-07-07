local ts = vim.treesitter
local M = {}

-- Get function name from different node types
M.get_function_name = function(node)
  local node_type = node:type()

  if node_type == "function_declaration" then
    local name_node = node:field("name")[1]
    if name_node then
      return ts.get_node_text(name_node, 0)
    end
  elseif node_type == "method_definition" then
    local name_node = node:field("name")[1]
    if name_node then
      return ts.get_node_text(name_node, 0)
    end
  elseif node_type == "arrow_function" or node_type == "function_expression" then
    -- Try to find assignment or property name
    local parent = node:parent()
    if parent then
      if parent:type() == "variable_declarator" then
        local name_node = parent:field("name")[1]
        if name_node then
          return ts.get_node_text(name_node, 0)
        end
      elseif parent:type() == "assignment_expression" then
        local left = parent:field("left")[1]
        if left then
          return ts.get_node_text(left, 0)
        end
      elseif parent:type() == "property_definition" or parent:type() == "pair" then
        local key = parent:field("key")[1]
        if key then
          return ts.get_node_text(key, 0)
        end
      end
    end
    return "anonymous"
  end

  return "unknown"
end

-- Get parameter names from function parameters
M.get_param_names = function(node)
  local params = {}
  local param_nodes = node:field("parameters")

  if not param_nodes or #param_nodes == 0 then
    return params
  end

  local formal_params = param_nodes[1]
  if formal_params:type() ~= "formal_parameters" then
    return params
  end

  for child in formal_params:iter_children() do
    if child:type() == "required_parameter" or child:type() == "optional_parameter" then
      local pattern = child:field("pattern")[1]
      if pattern then
        if pattern:type() == "identifier" then
          table.insert(params, {
            name = ts.get_node_text(pattern, 0),
            node = pattern,
          })
        elseif pattern:type() == "object_pattern" then
          -- Handle destructuring
          for prop in pattern:iter_children() do
            if prop:type() == "object_assignment_pattern" then
              local left = prop:field("left")[1]
              if left and left:type() == "shorthand_property_identifier_pattern" then
                table.insert(params, {
                  name = ts.get_node_text(left, 0),
                  node = left,
                })
              end
            elseif prop:type() == "shorthand_property_identifier_pattern" then
              table.insert(params, {
                name = ts.get_node_text(prop, 0),
                node = prop,
              })
            end
          end
        elseif pattern:type() == "array_pattern" then
          -- Handle array destructuring
          for _, elem in ipairs(pattern:field("elements") or {}) do
            if elem:type() == "identifier" then
              table.insert(params, {
                name = ts.get_node_text(elem, 0),
                node = elem,
              })
            end
          end
        end
      end
    end
  end

  return params
end

-- Find all identifier usages within a function body
M.find_identifier_usages = function(body_node, param_name)
  local usages = {}

  local function traverse(node)
    if node:type() == "identifier" then
      local text = ts.get_node_text(node, 0)
      if text == param_name then
        local start_row, start_col = node:start()
        table.insert(usages, { row = start_row, col = start_col })
      end
    end

    for child in node:iter_children() do
      traverse(child)
    end
  end

  traverse(body_node)
  return usages
end

-- Check if a node has more than N lines
function M.is_large_enough(node, min_lines)
  local start_row, _, end_row, _ = node:range()
  return (end_row - start_row + 1) > min_lines
end

-- Check if node is exported
function M.is_exported(node)
  local parent = node:parent()
  while parent do
    if parent:type() == "export_statement" or parent:type() == "export_clause" then
      return true
    end
    parent = parent:parent()
  end
  return false
end

M.query_for_functions = function (bufnr)
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

    -- Query exported functions with bodies
    local function_query_string = [[
    ;; Match exported function declarations with body
    (
        (function_declaration
        name: (identifier) @name
        body: (statement_block) @body
        (#offset! @body)
        )
        (#match? @name ".*") ;; ensures name is valid (optional)
        (#has-export? @name)
    )

    ;; Match exported arrow functions assigned to variables
    (
        (lexical_declaration
        (variable_declarator
            name: (identifier) @name
            value: (arrow_function
            body: (statement_block) @body
            )
        )
        )
        (#has-export? @name)
    )

    ;; Match exported methods inside classes
    (
        (method_definition
        name: (property_identifier) @name
        body: (statement_block) @body
        )
        (#has-export? @name)
    )
    ]]

    -- Parse the query
    local ok, function_query = pcall(ts.query.parse, "typescript", function_query_string)
    if not ok then
      vim.notify("Failed to parse Tree-sitter query", vim.log.levels.ERROR)
      return
    end

    return {
        root = root,
        function_query = function_query
    }
end

M.find_function_at_cursor = function(root, cursor_row)
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

return M
