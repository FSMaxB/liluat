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

-- creates an iterator that iterates over all chunks in the given template
-- a chunk is either a template delimited by start_tag and end_tag or a normal text
local function all_chunks(template, start_tag, end_tag)
	-- pattern to match a template chunk
	local pattern = escape_pattern(start_tag) .. ".-" .. escape_pattern(end_tag)
	local position = 1

	return function ()
		if not position then
			return nil
		end

		local template_start, template_end = template:find(pattern, position)

		if template_start == position then -- next chunk is a template chunk
			position = template_end + 1
			return template:sub(template_start, template_end)
		elseif template_start then -- next chunk is a text chunk
			local chunk = template:sub(position, template_start - 1)
			position = template_start
			return chunk
		else -- no template chunk found --> either text chunk until end of file or no chunk at all
			chunk = template:sub(position)
			position = nil
			return (#chunk > 0) and chunk or nil
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

-- a tree fold on inclusion tree
-- @param init_func: must return a new value when called
local function include_fold(template, start_tag, end_tag, fold_func, init_func)
	local result = init_func()

	start_tag = start_tag or '#{'
	end_tag = end_tag or '}#'
	local start_tag_inc = start_tag..'include:'

	local start1, end1 = string.find(template, start_tag_inc, 1, true)
	local start2 = nil
	local end2 = 0

	while start1 ~= nil do
		if start1 > end2 + 1 then -- for beginning part of file
			result = fold_func(result, string.sub(template, end2 + 1, start1 - 1))
		end
		start2, end2 = string.find(template, end_tag, end1 + 1, true)
		assert(start2, 'end tag "'..end_tag..'" missing')
		do -- recursively include the file
			local filename = assert(loadstring('return '..string.sub(template, end1 + 1, start2 - 1)))()
			assert(filename)
			local fin = assert(io.open(filename))
			-- TODO: detect cyclic inclusion?
			result = fold_func(result, include_fold(fin:read('*a'), start_tag, end_tag, fold_func, init_func), filename)
			fin:close()
		end
		start1, end1 = string.find(template, start_tag_inc, end2 + 1, true)
	end
	result = fold_func(result, string.sub(template, end2 + 1))
	return result
end
liluat.private.include_fold = include_fold

-- preprocess included files
-- @return string
function liluat.precompile(template, start_tag, end_tag)
	return table.concat(include_fold(template, start_tag, end_tag, function(acc, v)
		if type(v) == 'string' then
			table.insert(acc, v)
		elseif type(v) == 'table' then
			table.insert(acc, table.concat(v))
		else
			error('Unknown type: '..type(v))
		end
		return acc
	end, function() return {} end))
end

-- unique a list, preserve order
local function stable_uniq(t)
	local existed = {}
	local res = {}
	for _, v in ipairs(t) do
		if not existed[v] then
			table.insert(res, v)
			existed[v] = true
		end
	end
	return res
end
liluat.private.stable_uniq = stable_uniq

-- @return { string }
function liluat.get_dependency(template, start_tag, end_tag)
	return stable_uniq(include_fold(template, start_tag, end_tag, function(acc, v, name)
		if type(v) == 'string' then
		elseif type(v) == 'table' then
			if name ~= nil then
				table.insert(acc, name)
			end
			for _, subname in ipairs(v) do
				table.insert(acc, subname)
			end
		else
			error('Unknown type: '..type(v))
		end
		return acc
	end, function() return {} end))
end

-- @return { name = string, code = string / function}
function liluat.loadstring(template, start_tag, end_tag, tmpl_name)
	-- compile it to lua code
	local lua_code = {}

	start_tag = start_tag or '#{'
	end_tag = end_tag or '}#'

	local output_func = "coroutine.yield"

	template = liluat.precompile(template, start_tag, end_tag)

	local start1, end1 = string.find(template, start_tag, 1, true)
	local start2 = nil
	local end2 = 0

	local cEqual = string.byte('=', 1)

	while start1 ~= nil do
		if start1 > end2 + 1 then
			table.insert(lua_code, output_func..'('..string.format("%q", string.sub(template, end2 + 1, start1 - 1))..')')
		end
		start2, end2 = string.find(template, end_tag, end1 + 1, true)
		assert(start2, 'end_tag "'..end_tag..'" missing')
		if string.byte(template, end1 + 1) == cEqual then
			table.insert(lua_code, output_func..'('..string.sub(template, end1 + 2, start2 - 1)..')')
		else
			table.insert(lua_code, string.sub(template, end1 + 1, start2 - 1))
		end
		start1, end1 = string.find(template, start_tag, end2 + 1, true)
	end
	table.insert(lua_code, output_func..'('..string.format("%q", string.sub(template, end2 + 1))..')')

	return {
		name = tmpl_name or '=(liluat.loadstring)',
		code = table.concat(lua_code, '\n')
	}
end

-- @return { name = string, code = string / function }
function liluat.loadfile(filename, start_tag, end_tag)
	local fin = assert(io.open(filename))
	local all = fin:read('*a')
	fin:close()
	return liluat.loadstring(all, start_tag, end_tag, filename)
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
