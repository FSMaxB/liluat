#!/usr/bin/env lua

--[[
-- runliluat - Use liluat from the command line
--
-- Project page: https://github.com/FSMaxB/liluat
--
-- liluat is based on slt2 by henix, see https://github.com/henix/slt2
--
-- Copyright © 2016 Max Bruckner
-- Copyright © 2011-2016 henix
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is furnished
-- to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
-- IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local liluat = require('liluat')

local function print_usage()
	print([[
Usage: runliluat [options]
Options:
	-h|--help
		Show this message.
	--values lua_table
		Table containing values to use in the template.
	--value-file file_name
		Use a file to define the table of values to use in the template.
	-t|--template-file file_name
		File that contains the template
	-n|--name template_name
		Name to use for the template
	-d|--dependencies
		List the dependencies of the template (list of included files)
	-i|--inline
		Inline all the included files into one template.
	-o|--output filename
		File to write the output to (defaults to stdout)
	--options lua_table
		A table of options for liluat
	--options-file file_name
		Read the options from a file.
	--stdin "template"
		Get the template from stdin.
	--stdin "values"
		Get the table of values from stdin.
	--stdin "options"
		Get the options from stdin.
	-v|--version
		Print the current version.
	--path path
		Root path of the templates.
]])
end

local function print_error(error_message, fallback_message)
	if error_message then
		io.stderr:write("ERROR: "..error_message.."\n")
	elseif fallback_message then
		io.stderr:write("ERROR: "..fallback_message.."\n")
	else
		io.stderr:write("ERROR: An unknown error happened.\n")
	end
end

if #arg == 0 then
	print_error("No parameter given.")
	print_usage()
	os.exit(1)
end


local value_string
local options_string
local template
local list_dependencies = false
local inline = false
local print_version = false
local output_file
local path
local template_path
local template_name
-- go through all the command line parameters
repeat
	if (arg[1] == "-h") or (arg[1] == "--help") then
		print_usage()
		os.exit(0)
	elseif arg[1] == "--values" then
		value_string = arg[2]
		table.remove(arg, 2)
	elseif arg[1] == "--value-file" then
		local success
		success, value_string = pcall(function () return liluat.private.read_entire_file(arg[2]) end)
		if not success then
			print_error(value_string, "Failed to read value file "..string.format("%q", arg[2])..".")
			os.exit(1)
		end
		table.remove(arg, 2)
	elseif (arg[1] == "-n") or (arg[1] == "--name") then
		template_name = arg[2]
		table.remove(arg, 2)
	elseif (arg[1] == "-t") or (arg[1] == "--template-file") then
		template_path = arg[2]
		table.remove(arg, 2)
	elseif (arg[1] == "-d") or (arg[1] == "--dependencies") then
		list_dependencies = true
	elseif (arg[1] == "-i") or (arg[1] == "--inline") then
		inline = true
	elseif (arg[1] == "-o") or (arg[1] == "--output") then
		output_file = arg[2]
		table.remove(arg, 2)
	elseif arg[1] == "--options" then
		options_string = arg[2]
		table.remove(arg, 2)
	elseif arg[1] == "--options-file" then
		local success
		success, options_string = pcall(function () return liluat.private.read_entire_file(arg[2]) end)
		if not success then
			print_error(options, "Failed to read options file "..string.format("%q", arg[2])..".")
			os.exit(1)
		end
		table.remove(arg, 2)
	elseif arg[1] == "--stdin" then
		local success
		if arg[2] == "template" then
			template = io.stdin:read("*all")
		elseif arg[2] == "values" then
			value_string = io.stdin:read("*all")
		elseif arg[2] == "options" then
			options_string = io.stdin:read("*all")
		else
			print_error('Invalid paramter for "--stdin".')
			os.exit(1)
		end
		table.remove(arg, 2)
	elseif (arg[1] == "-v") or (arg[1] == "--version") then
		print_version = true
	elseif arg[1] == "--path" then
		path = arg[2]
		table.remove(arg, 2)
	else
		print_error("Invalid parameter "..string.format("%q", arg[1])..".")
		print_usage()
		os.exit(1)
	end

	table.remove(arg, 1)
until #arg == 0

--open the output file, if specified
local file, error_message
if output_file then
	file = io.open(output_file, "w+")
	if not file then
		print_error("Failed to open output file "..string.format("%q", output_file)..".")
	end
end

--write to stdout or the output file
local function write_out(text)
	if file then
		file:write(text)
	else
		io.write(text)
	end
end

--check if flags are compatible
if list_dependencies and inline and print_version then
	print_error("Can't print_version, determine dependencies and inline a template at the same time.")
	os.exit(1)
end

if list_dependencies and inline then
	print_error("Can't both determine dependencies and inline a template.")
	os.exit(1)
end

if list_dependencies and print_version then
	print_error("Can't both determine dependencies and print the version.")
	os.exit(1)
end

if print_version and inline then
	print_error("Can't both print the version and inline a template.")
	os.exit(1)
end

if template_path and template then
	print_error("Can't both load a template from stdin and a file.")
	os.exit(1)
end
-----

if print_version then
	write_out(liluat.version().."\n")
	os.exit(0)
end

if (not template) and (not template_path) then
	print_error("No template specified.")
	os.exit(1)
end

local options = {}
if options_string then
	options = liluat.private.sandbox("return "..options_string, "options")()
end

-- template to be loaded from a file
if template_path and (list_dependencies or inline) then
	local success
	success, template = pcall(function () return liluat.private.read_entire_file(template_path) end)
	if not success then
		print_error(template, "Failed to read template file "..string.format("%q", template_path)..".")
		os.exit(1)
	end
end

if list_dependencies then
	local dependencies = liluat.get_dependencies(template, options, path or template_path)
	write_out(table.concat(dependencies, "\n").."\n")
	os.exit(0)
end

if inline then
	write_out(liluat.inline(template, options, path or template_path))
	os.exit(0)
end

local values = {}
if value_string then
	values = liluat.private.sandbox("return "..value_string, "values")()
end

-- now process the template
if template_path then
	write_out(liluat.render(liluat.compile_file(template_path, options), values))
else
	write_out(liluat.render(liluat.compile(template, options, template_name, path), values))
end
os.exit(0)
