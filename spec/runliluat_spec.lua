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
