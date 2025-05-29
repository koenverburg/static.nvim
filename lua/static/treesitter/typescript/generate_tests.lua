local parsers = require("nvim-treesitter.parsers")
local utils = require('static.treesitter.typescript.utils')

local M = {}

-- Generate return type test
local function generate_return_type_test(func_info)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	local params = {}
	for _, param in ipairs(func_info.params) do
		table.insert(params, utils.get_sample_value_for_type(param.type).value)
	end

	local call_params = table.concat(params, ", ")

	if func_info.is_async then
		table.insert(lines, "const result = await " .. func_name .. "(" .. call_params .. ");")
	else
		table.insert(lines, "const result = " .. func_name .. "(" .. call_params .. ");")
	end

	table.insert(lines, "")
	local type_check = utils.get_type_check_for_type(func_info.return_type)
	table.insert(lines, "expect(" .. type_check .. ").toBe(true);")

	return lines
end


-- Generate error test
local function generate_error_test(func_info)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	table.insert(lines, "expect(() => {")
	table.insert(lines, "  " .. func_name .. "();")
	table.insert(lines, "}).toThrow();")

	return lines
end

-- Generate async test
local function generate_async_test(func_info)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	local params = {}
	for _, param in ipairs(func_info.params) do
		table.insert(params, utils.get_sample_value_for_type(param.type).value)
	end

	local call_params = table.concat(params, ", ")

	table.insert(lines, "const result = await " .. func_name .. "(" .. call_params .. ");")
	table.insert(lines, "")
	table.insert(lines, "expect(result).toBeDefined();")
	table.insert(lines, "// Add more specific async assertions here")

	return lines
end

-- Generate edge case test
local function generate_edge_case_test(func_info, param, edge_case)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	local params = {}
	for _, p in ipairs(func_info.params) do
		if p.name == param.name then
			table.insert(params, edge_case.value)
		else
			table.insert(params, utils.get_sample_value_for_type(p.type).value)
		end
	end

	local call_params = table.concat(params, ", ")

	if edge_case.should_throw then
		table.insert(lines, "expect(() => " .. func_name .. "(" .. call_params .. ")).toThrow();")
	else
		table.insert(lines, "const result = " .. func_name .. "(" .. call_params .. ");")
		table.insert(lines, "expect(result)" .. edge_case.expectation .. ";")
	end

	return lines
end

-- Generate happy path test
local function generate_happy_path_test(func_info)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	-- Generate sample parameters
	local params = {}
	local setup_lines = {}

	for _, param in ipairs(func_info.params) do
		local sample_value = utils.get_sample_value_for_type(param.type)
		table.insert(params, sample_value.value)
		if sample_value.setup then
			table.insert(setup_lines, sample_value.setup)
		end
	end

	-- Add setup lines
	for _, setup in ipairs(setup_lines) do
		table.insert(lines, setup)
	end

	if #setup_lines > 0 then
		table.insert(lines, "")
	end

	-- Generate function call
	local call_params = table.concat(params, ", ")
	local expected_result = utils.get_expected_result_for_type(func_info.return_type)

	if func_info.is_async then
		table.insert(lines, "const result = await " .. func_name .. "(" .. call_params .. ");")
	else
		table.insert(lines, "const result = " .. func_name .. "(" .. call_params .. ");")
	end

	table.insert(lines, "")
	table.insert(lines, "expect(result)" .. expected_result .. ";")

	return lines
end


-- Generate null/undefined tests
local function generate_null_undefined_tests(func_info)
	local lines = {}
	local func_name = func_info.name or "unknownFunction"

	for i, param in ipairs(func_info.params) do
		if not param.optional then
			local params = {}
			for j, p in ipairs(func_info.params) do
				if j == i then
					table.insert(params, "null")
				else
					table.insert(params, utils.get_sample_value_for_type(p.type).value)
				end
			end

			local call_params = table.concat(params, ", ")
			if func_info.throws then
				table.insert(lines, "expect(() => " .. func_name .. "(" .. call_params .. ")).toThrow();")
			else
				table.insert(lines, "const result = " .. func_name .. "(" .. call_params .. ");")
				table.insert(lines, "expect(result).toBeDefined();")
			end
			table.insert(lines, "")
		end
	end

	return lines
end

-- Generate test cases based on function info
local function generate_test_cases(func_info)
	local test_cases = {}
	-- local func_name = func_info.name or "unknownFunction"

	-- Happy path test
	table.insert(test_cases, {
		description = "it('should work with valid inputs', () => {",
		code = generate_happy_path_test(func_info),
	})

	-- Edge cases based on parameters
	if #func_info.params > 0 then
		-- Null/undefined parameter tests
		table.insert(test_cases, {
			description = "it('should handle null/undefined parameters', () => {",
			code = generate_null_undefined_tests(func_info),
		})

		-- Type-specific edge cases
		for _, param in ipairs(func_info.params) do
			local edge_cases = utils.get_edge_cases_for_type(param.type)
			for _, edge_case in ipairs(edge_cases) do
				table.insert(test_cases, {
					description = "it('should handle "
						.. edge_case.description
						.. " for "
						.. param.name
						.. "', () => {",
					code = generate_edge_case_test(func_info, param, edge_case),
				})
			end
		end
	end

	-- Error handling tests
	if func_info.throws then
		table.insert(test_cases, {
			description = "it('should throw error for invalid input', () => {",
			code = generate_error_test(func_info),
		})
	end

	-- Async function tests
	if func_info.is_async then
		table.insert(test_cases, {
			description = "it('should handle async operations correctly', async () => {",
			code = generate_async_test(func_info),
		})
	end

	-- Return type validation
	if func_info.return_type and func_info.return_type ~= "void" then
		table.insert(test_cases, {
			description = "it('should return correct type', () => {",
			code = generate_return_type_test(func_info),
		})
	end

	return test_cases
end

-- Generate test code for a function
local function generate_test_code(func_node)
	local func_info = utils.extract_function_info(func_node)
	if not func_info then
		return nil
	end

	local test_lines = {}
	local func_name = func_info.name or "unknownFunction"
	local import_name = utils.get_import_name_for_function(func_node)

	-- Test file header
	table.insert(test_lines, "import { " .. import_name .. " } from './" .. utils.get_current_filename_without_ext() .. "';")
	table.insert(test_lines, "")

	-- Main describe block
	table.insert(test_lines, "describe('" .. func_name .. "', () => {")

	-- Generate different test cases based on function analysis
	local test_cases = generate_test_cases(func_info)

	for _, test_case in ipairs(test_cases) do
		table.insert(test_lines, "  " .. test_case.description)
		for _, line in ipairs(test_case.code) do
			table.insert(test_lines, "    " .. line)
		end
		table.insert(test_lines, "  });")
		table.insert(test_lines, "")
	end

	table.insert(test_lines, "});")

	return table.concat(test_lines, "\n")
end

-- Create or open test file
local function create_or_open_test_file(test_code)
	local current_file = vim.api.nvim_buf_get_name(0)
	local current_dir = vim.fn.fnamemodify(current_file, ":h")
	local current_name = vim.fn.fnamemodify(current_file, ":t:r")

	-- Common test file patterns
	local test_patterns = {
		current_dir .. "/" .. current_name .. ".test.ts",
		current_dir .. "/" .. current_name .. ".spec.ts",
		current_dir .. "/__tests__/" .. current_name .. ".test.ts",
		current_dir .. "/tests/" .. current_name .. ".test.ts",
	}

	local test_file = nil

	-- Check if any test file already exists
	for _, pattern in ipairs(test_patterns) do
		if vim.fn.filereadable(pattern) == 1 then
			test_file = pattern
			break
		end
	end

	-- If no test file exists, create the first pattern
	if not test_file then
		test_file = test_patterns[1]
	end

	-- Create directory if it doesn't exist
	local test_dir = vim.fn.fnamemodify(test_file, ":h")
	vim.fn.mkdir(test_dir, "p")

	-- Check if file exists and has content
	if vim.fn.filereadable(test_file) == 1 and vim.fn.getfsize(test_file) > 0 then
		-- File exists, ask user what to do
		local choice = vim.fn.confirm(
			"Test file exists. What would you like to do?",
			"&Append\n&Replace\n&Open existing\n&Cancel",
			3
		)

		if choice == 1 then -- Append
			vim.cmd("edit " .. test_file)
			vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "// Additional tests", "" })
			vim.api.nvim_buf_set_lines(0, -1, -1, false, vim.split(test_code, "\n"))
		elseif choice == 2 then -- Replace
			vim.cmd("edit " .. test_file)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(test_code, "\n"))
		elseif choice == 3 then -- Open existing
			vim.cmd("edit " .. test_file)
			return
		else -- Cancel
			return
		end
	else
		-- Create new file
		vim.cmd("edit " .. test_file)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(test_code, "\n"))
	end

	print("Test file: " .. test_file)
end

-- Generate tests for function at cursor
function M.generate_tests()
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

	local test_code = generate_test_code(function_node)
	if test_code then
		create_or_open_test_file(test_code)
	end
end

-- vim.keymap.set("n", "<leader>tt", M.generate_tests, { desc = "Generate tests for function at cursor" })
vim.api.nvim_create_user_command("TSGenerateTests", M.generate_tests, {})

return M
