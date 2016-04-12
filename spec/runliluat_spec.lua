--[[
-- Tests for runliluat using the "busted" unit testing framework.
--
-- Copyright © 2016 Max Bruckner
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

-- preload to make sure that 'require' loads the local liluat and not the globally installed one
package.loaded["liluat"] = loadfile("liluat.lua")()
local liluat = require("liluat")

-- custom exec function that works across lua versions
local function execute_command(command)
	local exit_status
	if _VERSION == "Lua 5.1" then
		exit_status = os.execute(command)
	else
		_,_, exit_status = os.execute(command)
	end

	return exit_status
end

-- create a temporary file, open it and return a file descriptor as well as the filename
local function tempfile()
	local filename = os.tmpname()
	local file = io.open(filename, "w+")

	return file, filename
end

-- execute a command while specifying its input and output
local function execute_with_in_and_output(command, input)
	-- create input file and write the input to it
	local input_file, input_file_name
	if input then
		input_file, input_file_name = tempfile()
		input_file:write(input)
		input_file:close()
	end

	local stdout_file, stdout_file_name = tempfile()
	local stderr_file, stderr_file_name = tempfile()

	if input_file then
		command = "cat " .. input_file_name .. " | " .. command
	end
	command = command
		.. " 1> " .. stdout_file_name
		.. " 2> " .. stderr_file_name


	local exit_status = execute_command(command)

	if input_file_name then
		os.remove(input_file_name)
	end
	stdout_file:close()
	stderr_file:close()

	local stdout = liluat.private.read_entire_file(stdout_file_name)
	os.remove(stdout_file_name)
	local stderr = liluat.private.read_entire_file(stderr_file_name)
	os.remove(stderr_file_name)

	return exit_status, stdout, stderr
end

local function get_error_code()
	return (_VERSION == "Lua 5.1") and 256 or 1
end

local usage_string = [[
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

]]

describe("runliluat test helpers", function ()
	it("should execute commands", function ()
		assert.equal(0, execute_command("true"))
		assert.not_equal(0, execute_command("false"))
	end)

	it("should get the output of a command", function ()
		local expected_output = {
			0, "hello\n", ""
		}

		assert.same(expected_output, {execute_with_in_and_output("echo hello")})
	end)

	it("should get the error output of a command", function ()
		local expected_output = {
			0, "", "hello\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("sh -c 'echo hello >&2'")})
	end)
end)

describe("runliluat", function ()
	it("should complain when no parameters were given", function ()
		local expected_output = {
			get_error_code(), usage_string, "ERROR: No parameter given.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua")})
	end)

	it("should complain on incorrect parameters", function ()
		local expected_output = {
			get_error_code(), usage_string, 'ERROR: Invalid parameter "-a".\n'
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -a")})
	end)

	it("should print the help", function ()
		local expected_output = {
			0, usage_string, ""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -h")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --help")})
	end)

	it("should print it's version", function ()
		local expected_output = {
			0,
			liluat.version().."\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version")})
	end)

	it("should have a rockspec file for the current version", function ()
		local exit_status, stdout, stderr = execute_with_in_and_output("ls liluat-`spec/preload.lua -v`-*.rockspec")
		assert.is_truthy(stdout:find("^liluat%-[%w%.]+%-%d+%.rockspec"))
		assert.equal(0, exit_status)
		assert.equal("", stderr)
	end)

	it("should complain when trying to print version, get dependencies and inline", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: Can't print_version, determine dependencies and inline a template at the same time.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v -d -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version -d -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version --dependencies -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version --dependencies --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version -d --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v -d --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v --dependencies --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v --dependencies -i")})
	end)

	it("should complain when trying to get dependencies and inline", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: Can't both determine dependencies and inline a template.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies --inline")})
	end)

	it("should complain when trying to get dependencies and print the version", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: Can't both determine dependencies and print the version.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d -v")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d --version")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies -v")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies --version")})
	end)

	it("should complain when trying to print the version and inline", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: Can't both print the version and inline a template.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -v --inline")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version -i")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --version --inline")})
	end)

	it("should complain when trying to load a template from a file and stdin", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: Can't both load a template from stdin and a file.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -t spec/index.html.template --stdin template", "{{}}")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --template-file spec/index.html.template --stdin template", "{{}}")})
	end)

	it("should print dependencies", function ()
		local template = '{{include: "spec/index.html.template"}}'
		local expected_output = {
			0,
			"spec/index.html.template\n"
			.. "spec/content.html.template\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d --stdin template", template)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies --stdin template", template)})
	end)

	it("should get dependencies when loading a template from a file", function ()
		local template_path = "spec/index.html.template"
		local expected_output = {
			0,
			"spec/content.html.template\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d -t "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies -t "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d --template-file "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --dependencies --template-file "..template_path)})
	end)

	it("should inline a template", function ()
			local template = liluat.private.read_entire_file("spec/index.html.template")
			local expected_output = {
				0,
				liluat.private.read_entire_file("spec/index.html.template.inlined"),
				""
			}

			assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --path 'spec/' --stdin template -i", template)})
			assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --path 'spec/' --stdin template --inline", template)})
	end)

	it("should inline a template when loading it from a file", function ()
		local template_path = "spec/index.html.template"
		local expected_output = {
			0,
			liluat.private.read_entire_file("spec/index.html.template.inlined"),
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -i -t "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -i --template-file "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --inline -t "..template_path)})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --inline --template-file "..template_path)})
	end)

	it("should accept template paths via --path", function ()
		local template_path = 'spec/basepath_tests/base_a.template'
		local template = liluat.private.read_entire_file(template_path)
		local expected_output = {
			0,
			"<h1>This is the index page.</h1>\n\n\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --path '"..template_path.."' --stdin template ", template)})
	end)

	it("should complain when no template is specified", function ()
		local expected_output = {
			get_error_code(),
			"",
			"ERROR: No template specified.\n"
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -d")})
	end)

	it("should not crash when a template name is specified", function ()
		local expected_output = {
			0,
			"",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin template -n 'test'", "")})
		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin template --name 'test'", "")})
	end)

	it("should load values from a file", function ()
		local template = "{{= name}}"
		local value_path = "spec/values"
		local expected_output = {
			0,
			"max",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin template --value-file "..value_path, template)})
	end)

	it("should load values from stdin", function ()
		local template_path = "spec/template"
		local values = '{name = "max"}'
		local expected_output = {
			0,
			"max\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin values -t "..template_path, values)})
	end)

	it("should load values from a parameter", function ()
		local template = "{{= name}}"
		local values = '{name = "max"}'

		local expected_output = {
			0,
			"max",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin template --values '"..values.."'", template)})
	end)

	it("should load options from a file", function ()
		local options_path = "spec/options"
		local template = '{%= name%}'
		local values = '{name = "max"}'

		local expected_output = {
			0,
			"max",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin template --options-file "..options_path.." --values '"..values.."'", template)})
	end)

	it("should load options from stdin", function ()
		local options = '{start_tag = "{%", end_tag = "%}"}'
		local template_path = "spec/template-jinja"
		local values = '{name = "max"}'

		local expected_output = {
			0,
			"max\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --stdin options -t "..template_path.." --values '"..values.."'", options)})
	end)

	it("should load options from a parameter", function ()
		local options = '{start_tag = "{%", end_tag = "%}"}'
		local template_path = "spec/template-jinja"
		local values = '{name = "max"}'

		local expected_output = {
			0,
			"max\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --options '"..options.."' -t "..template_path.." --stdin values", values)})
	end)

	it("should load templates from a file", function ()
		local template_path = 'spec/template'
		local values = '{name = "max"}'

		local expected_output = {
			0,
			"max\n",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua -t "..template_path.." --stdin values", values)})
	end)

	it("should load templates from stdin", function ()
		local template = "{{= name}}"
		local value_path = "spec/values"

		local expected_output = {
			0,
			"max",
			""
		}

		assert.same(expected_output, {execute_with_in_and_output("spec/preload.lua --value-file "..value_path.." --stdin template", template)})
	end)

	it("should write it's output to a file", function ()
		local file, filename = tempfile()
		file:close()

		execute_with_in_and_output("spec/preload.lua -o "..filename.. " -v")
		assert.equal(liluat.version().."\n", liluat.private.read_entire_file(filename))

		execute_with_in_and_output("spec/preload.lua --output "..filename.. " -v")
		assert.equal(liluat.version().."\n", liluat.private.read_entire_file(filename))

		os.remove(filename)
	end)
end)
