--[[
-- liluat - Lightweight Lua Template engine
--
-- Project page: https://github.com/FSMaxB/liluat
--
-- liluat is based on slt2 by henix, see https://github.com/henix/slt2
-- @License
-- MIT License
--]]

local liluat = {
	private = {} --used to expose private functions for testing
}

-- escape a string for use in lua patterns
-- (this simply prepends all non alphanumeric characters with '%'
local function escape_pattern(text)
	return text:gsub("([^%w])", "%%%1" --[[function (match) return "%"..match end--]])
end
liluat.private.escape_pattern = escape_pattern

-- initialise table of options (use the provided, default otherwise)
local function initialise_options(options)
	options = options or {}
	options.start_tag = options.start_tag or "#{"
	options.end_tag = options.end_tag or "}#"
	options.template_name = options.template_name or "default_name"

	return options
end

-- creates an iterator that iterates over all chunks in the given template
-- a chunk is either a template delimited by start_tag and end_tag or a normal text
-- the iterator also returns the type of the chunk as second return value
local function all_chunks(template, options)
	options = initialise_options(options)

	-- pattern to match a template chunk
	local template_pattern = escape_pattern(options.start_tag) .. ".-" .. escape_pattern(options.end_tag)
	local include_pattern = escape_pattern(options.start_tag) .. "include:.-" .. escape_pattern(options.end_tag)
	local expression_pattern = escape_pattern(options.start_tag) .. "=.-" .. escape_pattern(options.end_tag)
	local position = 1

	return function ()
		if not position then
			return nil
		end

		local template_start, template_end = template:find(template_pattern, position)
		local chunk_type --type of the chunk (text, code, expression, include)

		if template_start == position then -- next chunk is a template chunk
			if template_start == template:find(include_pattern, position) then
				chunk_type = "include"
			elseif template_start == template:find(expression_pattern, position) then
				chunk_type = "expression"
			else
				chunk_type = "code"
			end

			position = template_end + 1
			return {text = template:sub(template_start, template_end), type = chunk_type }
		elseif template_start then -- next chunk is a text chunk
			local chunk = template:sub(position, template_start - 1)
			position = template_start
			return {text = chunk, type = "text"}
		else -- no template chunk found --> either text chunk until end of file or no chunk at all
			chunk = template:sub(position)
			position = nil
			return (#chunk > 0) and {text = chunk, type = "text"} or nil
		end
	end
end
liluat.private.all_chunks = all_chunks

local function read_entire_file(path)
	assert(path)
	local file = assert(io.open(path))
	local file_content = file:read('*a')
	file:close()
	return file_content
end
liluat.private.read_entire_file = read_entire_file

-- recursively copy a table
local function clone_table(table)
	local clone = {}

	for key, value in pairs(table) do
		if type(value) == "table" then
			clone[key] = clone_table(value)
		else
			clone[key] = value
		end
	end

	return clone
end
liluat.private.clone_table = clone_table

-- recursively merge two tables, the second one has precedence
local function merge_tables(a, b)
	a = a or {}
	b = b or {}

	local merged = clone_table(a)

	for key, value in pairs(b) do
		if type(value) == "table" then
			if a[key] then
				merged[key] = merge_tables(a[key], value)
			else
				merged[key] = clone_table(value)
			end
		else
			merged[key] = value
		end
	end

	return merged
end
liluat.private.merge_tables = merge_tables

-- a whitelist of allowed functions
local sandbox_whitelist = {
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	rawequal = rawequal,
	rawget = rawget,
	rawset = rawset,
	select = select,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	string = string,
	table = table,
	math = math,
	os = {
		date = os.date,
		difftime = os.difftime,
		time = os.time,
	},
	coroutine = coroutine
}

-- creates a function in a sandbox from a given code,
-- name of the execution context and an environment
-- that will be available inside the sandbox,
-- optionally overwrite the whitelis
local function sandbox(code, name, environment, whitelist)
	whitelist = whitelist or sandbox_whitelist

	-- prepare the environment
	environment = merge_tables(whitelist, environment)

	local func
	if setfenv then --Lua 5.1 and compatible
		if code:byte(1) == 27 then
			error("Lua bytecode not permitted.")
		end
		func = assert(loadstring(code))
		setfenv(func, environment)
	else -- Lua 5.2 and later
		func = assert(load(code, name, 't', environment))
	end

	return func
end
liluat.private.sandbox = sandbox

local function parse_string_literal(string_literal)
	return sandbox('return' .. string_literal, nil, nil, {})()
end
liluat.private.parse_string_literal = parse_string_literal

-- add an include to the include_list and throw an error if
-- an inclusion cycle is detected
local function add_include_and_detect_cycles(include_list, path)
	local parent = include_list[0]
	while parent do -- while the root hasn't been reached
		if parent[path] then
			error("Cyclic inclusion detected")
		end

		parent = parent[0]
	end

	include_list[path] = {
		[0] = include_list
	}
end
liluat.private.add_include_and_detect_cycles = add_include_and_detect_cycles

-- extract the name of a directory from a path
local function dirname(path)
	return path:match("^(.*/).-$") or ""
end
liluat.private.dirname = dirname

-- splits a template into chunks
-- chunks are either a template delimited by start_tag and end_tag
-- or a text chunk (everything else)
-- @return table
function liluat.lex(template, options, output, include_list)
	options = initialise_options(options)

	include_list = include_list or {} -- a list of files that were included
	local output = output or {}
	local include_pattern = "^" .. escape_pattern(options.start_tag) .. "include:(.-)" .. escape_pattern(options.end_tag)

	for chunk in all_chunks(template, options) do
		-- handle includes
		if chunk.type == "include" then -- include chunk
			local include_path_literal = chunk.text:match(include_pattern)
			local path = parse_string_literal(include_path_literal)

			add_include_and_detect_cycles(include_list, path)

			local included_template = read_entire_file(path)
			liluat.lex(included_template, options, output, include_list[path])
		elseif (chunk.type == "text") and output[#output] and (output[#output].type == "text") then
			-- ensure that no two text chunks follow each other
			output[#output].text = output[#output].text .. chunk.text
		else -- other chunk
			table.insert(output, chunk)
		end

	end

	return output
end

-- preprocess included files
-- @return string
function liluat.precompile(template, options)
	options = initialise_options(options)

	local output = ""
	for _,chunk in ipairs(liluat.lex(template, start_tag, end_tag)) do
		output = output .. chunk.text
	end

	return output
end

-- @return { string }
function liluat.get_dependency(template, options)
	options = initialise_options(options)

	local include_list = {}
	liluat.lex(template, options, nil, include_list)

	local dependencies = {}
	local have_seen = {} -- list of includes that were already added
	local function recursive_traversal(list)
		for key, value in pairs(list) do
			if (type(key) == "string") and (not have_seen[key]) then
				have_seen[key] = true
				table.insert(dependencies, key)
				recursive_traversal(value)
			end
		end
	end

	recursive_traversal(include_list)
	return dependencies
end

-- @return { name = string, code = string / function}
function liluat.loadstring(template, template_name, options)
	options = initialise_options(options)
	options.template_name = template_name or '=(liluat.loadstring)'

	local output_function = "coroutine.yield"

	-- split the template string into chunks
	local lexed_template = liluat.lex(template, options)

	-- pattern to match different kinds of templates
	local expression_pattern = escape_pattern(options.start_tag) .. "=(.-)" .. escape_pattern(options.end_tag)
	local code_pattern = escape_pattern(options.start_tag) .. "([^=].-)" .. escape_pattern(options.end_tag)

	-- table of code fragments the template is compiled into
	local lua_code = {}

	for i, chunk in ipairs(lexed_template) do
		-- check if the chunk is a template (either code or expression)
		if chunk.type == "expression" then
			local expression = chunk.text:match(expression_pattern)
			table.insert(lua_code, output_function..'('..expression..')')
		elseif chunk.type == "code" then
			table.insert(lua_code, chunk.text:match(code_pattern))
		else
			table.insert(lua_code, output_function..'('..string.format("%q", chunk.text)..')')
		end
	end

	return {
		name = options.template_name,
		code = table.concat(lua_code, '\n')
	}
end

-- @return { name = string, code = string / function }
function liluat.loadfile(filename, options)
	return liluat.loadstring(read_entire_file(filename), filename, options)
end

-- @return a coroutine function
function liluat.render_co(template, environment)
	return sandbox(template.code, template.name, environment)
end

-- @return string
function liluat.render(t, env)
	local result = {}
	local co = coroutine.create(liluat.render_co(t, env))
	while coroutine.status(co) ~= 'dead' do
		local ok, chunk = coroutine.resume(co)
		if not ok then
			error(chunk)
		end
		table.insert(result, chunk)
	end
	return table.concat(result)
end

return liluat
