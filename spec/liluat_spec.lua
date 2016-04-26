--[[
-- Tests for liluat using the "busted" unit testing framework.
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

describe("liluat", function ()
	it("should return an empty string for empty templates", function ()
		assert.equal("", liluat.render(liluat.compile(""), {}))
	end)

	it("should render some example template", function ()
		local tmpl = liluat.compile([[<span>
{{ if user ~= nil then }}
Hello, {{= escapeHTML(user.name) }}!
{{ else }}
<a href="/login">login</a>
{{ end }}
</span>
]])

		local expected_output = [[<span>
Hello, &lt;world&gt;!
</span>
]]

		local function escapeHTML(str)
			local tt = {
				['&'] = '&amp;',
				['<'] = '&lt;',
				['>'] = '&gt;',
				['"'] = '&quot;',
				["'"] = '&#39;',
			}
			local r = str:gsub('[&<>"\']', tt)
			return r
		end

		assert.equal(expected_output, liluat.render(tmpl, {user = {name = "<world>"}, escapeHTML = escapeHTML }))
	end)

	describe("string_lines", function ()
		it("should return ranges of lines", function ()
			local lines = "1\n2\n3\n4\n5\n6\n7"

			assert.equal("\n2\n3\n4\n", liluat.private.string_lines(lines, 2, 4))
		end)

		it("should return ranges of lines until end of string", function ()
			local lines = "1\n2\n3\n4\n5\n6\n7"

			assert.equal("\n5\n6\n7", liluat.private.string_lines(lines, 5, 7))
		end)

		it("should work with to large line numbers", function ()
			local lines = "1\n2\n3\n4\n5\n6\n7"

			assert.equal("\n6\n7", liluat.private.string_lines(lines, 6, 10))
		end)

		it("should work with negative line numbers", function ()
			local lines = "1\n2\n3\n4\n5\n6\n7"

			assert.equal("1\n2\n", liluat.private.string_lines(lines, -1, 2))
		end)
	end)

	describe("prepend_line_numbers", function()
		it("should prepend line numbers", function()
			local lines = [[
--2
--3
--4
--5
]]
			local expected = [[
  2:  --2
  3:  --3
  4:  --4
  5:  --5]]

			assert.equal(expected, liluat.private.prepend_line_numbers(lines, 2))
		end)

		it("should prepend line numbers with empty line in front", function()
			local lines = [[

--2
--3
--4
--5
]]
			local expected = [[
  2:  --2
  3:  --3
  4:  --4
  5:  --5]]

			assert.equal(expected, liluat.private.prepend_line_numbers(lines, 2))
		end)

		it("should prepend line numbers with empty line after it", function()
			local lines = [[
--2
--3
--4
--5
]]
			local expected = [[
  2:  --2
  3:  --3
  4:  --4
  5:  --5]]

			assert.equal(expected, liluat.private.prepend_line_numbers(lines, 2))
		end)

		it("should prepend line numbers and highlight a line", function()
			local lines = [[
--2
--3
--4
--5
]]
			local expected = [[
  2:  --2
  3:> --3
  4:  --4
  5:  --5]]

			assert.equal(expected, liluat.private.prepend_line_numbers(lines, 2, 3))
		end)

		it("should prepend line numbers and start with 1", function()
			local lines = [[
--1
--2
--3
--4
]]
			local expected = [[
  1:  --1
  2:  --2
  3:  --3
  4:  --4]]

			assert.equal(expected, liluat.private.prepend_line_numbers(lines))
		end)
	end)

	describe("clone_table", function ()
		it("should clone a table", function ()
			local table = {
				a = {
					b = 1,
					c = {
						d = 2
					}
				},
				e = 3
			}

			local clone = liluat.private.clone_table(table)

			assert.same(table, clone)
			assert.not_equal(table, clone)
			assert.not_equal(table.a, clone.a)
			assert.not_equal(table.a.c, clone.a.c)
		end)
	end)

	describe("merge_tables", function ()
		it("should merge two tables", function ()
			local a = {
				a = 1,
				b = 2,
				c = {
					d = 3,
					e = {
						f = 4
					}
				},
				g = {
					h = 5
				}
			}

			local b = {
				b = 3,
				x = 5,
				y = {
					z = 4
				},
				c = {
					j = 5
				}
			}

			local expected_output = {
				a = 1,
				b = 3,
				c = {
					d = 3,
					e = {
						f = 4
					},
					j = 5
				},
				g = {
					h = 5
				},
				x = 5,
				y = {
					z = 4
				}
			}

			assert.same(expected_output, liluat.private.merge_tables(a, b))
		end)

		it("should merge the second table as reference, if 'reference' parameter is set", function ()
			local a = {
				a = 1,
				b = 2,
				c = {
					d = 3,
					e = {
						f = 4
					}
				},
				g = {
					h = 5
				}
			}

			local b = {
				b = 3,
				x = 5,
				y = {
					z = 4
				},
				c = {
					j = 5
				}
			}

			local expected_output = {
			  a = 1,
			  b = 3,
			  c = {
			    j = 5
			  },
			  g = {
			    h = 5
			  },
			  x = 5,
			  y = {
			    z = 4
			  }
			}

			local merged_table = liluat.private.merge_tables(a, b, true)

			assert.same(expected_output, merged_table)

			-- make sure it is actually referenced
			assert.equal(b.c, merged_table.c)
		end)

		it("should merge nil tables", function ()
			local a = {
				a = 1
			}

			assert.same({a = 1}, liluat.private.merge_tables(nil, a))
			assert.same({a = 1}, liluat.private.merge_tables(a, nil))
			assert.same({}, liluat.private.merge_tables(nil, nil))
		end)
	end)

	describe("escape_pattern", function ()
		it("should escape lua pattern special characters", function ()
			local input = ".%a%c%d%l%p%s%u%w%x%z().%%+-*?[]^$"
			local expected_output = "%.%%a%%c%%d%%l%%p%%s%%u%%w%%x%%z%(%)%.%%%%%+%-%*%?%[%]%^%$"
			local escaped_pattern = liluat.private.escape_pattern(input)

			assert.equals(expected_output, escaped_pattern)
			assert.truthy(input:find(escaped_pattern))
		end)
	end)

	describe("all_chunks", function ()
		it("should iterate over all chunks", function ()
			local template = [[
{{= expression}} bla {{code}}
 {{other code}} some text
{{more code}}{{}}
{{include: "bla"}}
some more text]]
			local result = {}

			for chunk in liluat.private.all_chunks(template) do
				table.insert(result, chunk)
			end

			local expected_output = {
				{
					text = " expression",
					type = "expression"
				},
				{
					text = " bla ",
					type = "text"
				},
				{
					text = "code",
					type = "code"
				},
				{
					text = "\n ",
					type = "text"
				},
				{
					text = "other code",
					type = "code"
				},
				{
					text = " some text\n",
					type = "text"
				},
				{
					text = "more code",
					type = "code"
				},
				{
					text = "",
					type = "code"
				},
				{
					text = "\n",
					type = "text"
				},
				{
					text = ' "bla"',
					type = "include"
				},
				{
					text = "\nsome more text",
					type = "text"
				}
			}

			assert.same(expected_output, result)
		end)

		it("should detect manual trim_left", function ()
			local template = "\t{{-code}}"

			local chunks = {}
			for chunk in liluat.private.all_chunks(template) do
				table.insert(chunks, chunk)
			end

			local expected_output = {
				{
					text = "\t",
					type = "text"
				},
				{
					text = "code",
					type = "code",
					trim_left = true
				}
			}

			assert.same(expected_output, chunks)
		end)

		it("should detect manually disabled trim left", function ()
			local template = "\t{{+code}}"

			local chunks = {}
			for chunk in liluat.private.all_chunks(template) do
				table.insert(chunks, chunk)
			end

			local expected_output = {
				{
					text = "\t",
					type = "text"
				},
				{
					text = "code",
					type = "code",
					trim_left = false
				}
			}

			assert.same(expected_output, chunks)
		end)

		it("should detect manual trim_right", function ()
			local template = "{{code-}}\n"

			local chunks = {}
			for chunk in liluat.private.all_chunks(template) do
				table.insert(chunks, chunk)
			end

			local expected_output = {
				{
					text = "code",
					type = "code",
					trim_right = true
				},
				{
					text = "\n",
					type = "text"
				}
			}

			assert.same(expected_output, chunks)
		end)

		it("should detect manually disabled trim_right", function ()
			local template = "{{code+}}\n"

			local chunks = {}
			for chunk in liluat.private.all_chunks(template) do
				table.insert(chunks, chunk)
			end

			local expected_output = {
				{
					text = "code",
					type = "code",
					trim_right = false
				},
				{
					text = "\n",
					type = "text"
				}
			}

			assert.same(expected_output, chunks)
		end)

		it("should detect manual trim_left and trim_right", function ()
			local template = "\t{{-code-}}\n"

			local chunks = {}
			for chunk in liluat.private.all_chunks(template) do
				table.insert(chunks, chunk)
			end

			local expected_output = {
				{
					text = "\t",
					type = "text"
				},
				{
					text = "code",
					type = "code",
					trim_right = true,
					trim_left = true
				},
				{
					text = "\n",
					type = "text"
				}
			}

			assert.same(expected_output, chunks)
		end)
	end)

	describe("read_entire_file", function ()
		local file_content = liluat.private.read_entire_file("spec/read_entire_file-test")
		local expected = "This should be read by the 'read_entire_file' helper functions.\n"

		assert.equal(expected, file_content)
	end)

	describe("parse_string_literal", function()
		it("should properly resolve escape sequences", function ()
			local expected = "bl\"\'\\ub" .. "\n\t\r" .. "bla"
			local input = "\"bl\\\"\\\'\\\\ub\" .. \"\\n\\t\\r\" .. \"bla\""

			assert.equal(expected, liluat.private.parse_string_literal(input))
		end)
	end)

	describe("parse", function ()
		it("should create a list of chunks", function ()
			local template = [[
{{= expression}} bla {{code}}
 {{other code}} some text
{{more code}}{{}}
some more text]]

			local expected_output = {
				{
					text = " expression",
					type = "expression"
				},
				{
					text = " bla ",
					type = "text"
				},
				{
					text = "code",
					type = "code"
				},
				{
					text = "\n ",
					type = "text"
				},
				{
					text = "other code",
					type = "code"
				},
				{
					text = " some text\n",
					type = "text"
				},
				{
					text = "more code",
					type = "code"
				},
				{
					text = "",
					type = "code"
				},
				{
					text = "\nsome more text",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template))
		end)

		it("should include files", function ()
			local template = [[
first line
{{include: "spec/read_entire_file-test"}}
another line]]

			local expected_output = {
				{
					text = "first line\nThis should be read by the 'read_entire_file' helper functions.\n\nanother line",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template))
		end)

		it("should work with other start and end tags", function ()
			local template = "text {% --template%} more text"
			local expected_output = {
				{
					text = "text ",
					type = "text"
				},
				{
					text = " --template",
					type = "code"
				},
				{
					text = " more text",
					type = "text"
				}
			}

			local options = {
				start_tag = "{%",
				end_tag = "%}"
			}
			assert.same(expected_output, liluat.private.parse(template, options))
		end)

		it("should use existing table if specified", function ()
			local template = "bla {{= 5}} more bla"
			local output = {}
			local expected_output = {
				{
					text = "bla ",
					type = "text"
				},
				{
					text = " 5",
					type = "expression"
				},
				{
					text = " more bla",
					type = "text"
				}
			}

			local options = {
				start_tag = "{{",
				end_tag = "}}"
			}
			local result = liluat.private.parse(template, options, output)

			assert.equal(output, result)
			assert.same(expected_output, result)
		end)

		it("should detect cyclic inclusions", function ()
			local template = "{{include: 'spec/cycle_a.template'}}"

			assert.has_error(
				function ()
					liluat.private.parse(template)
				end,
				"Cyclic inclusion detected")
		end)

		it("should not create two or more text chunks in a row", function ()
			local template = 'text{{include: "spec/content.html.template"}}more text'

			local expected_output = {
				{
					text = "text<h1>This is the index page.</h1>\nmore text",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template))
		end)

		it("should include relative paths", function ()
			local template_path = "spec/basepath_tests/base_a.template"
			local template = liluat.private.read_entire_file(template_path)
			local expected_output = {
				{
					text = "<h1>This is the index page.</h1>\n\n\n",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template, nil, nil, nil, template_path))
		end)

		it("should include paths relative to a base path", function ()
			local options = {
				base_path = "spec/basepath_tests"
			}
			local template_path = options.base_path .. "/base_a.template"
			local template = liluat.private.read_entire_file(template_path)

			local expected_output = {
				{
					text = "<h1>This is the index page.</h1>\n\n\n",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template, options))
		end)

		it("should include more paths relative to a base path", function ()
			local options = {
				base_path = "spec"
			}
			local template_path = options.base_path .. "/basepath_tests/base_b.template"
			local template = liluat.private.read_entire_file(template_path)

			local expected_output = {
				{
					text = "<h1>This is the index page.</h1>\n\n\n",
					type = "text"
				}
			}

			assert.same(expected_output, liluat.private.parse(template, options))
		end)
	end)

	describe("sandbox", function ()
		it("should run code in a sandbox", function ()
			local code = "return i, 1"
			local i = 1
			local a, b = liluat.private.sandbox(code)()

			assert.is_nil(a)
			assert.equal(1, b)
		end)

		it("should pass an environment", function ()
			local code = "return i"
			assert.equal(1, liluat.private.sandbox(code, nil, {i = 1})())
		end)

		it("should not have access to non-whitelisted functions", function ()
			local code = "return load"
			assert.is_nil(liluat.private.sandbox(code)())
		end)

		it("should have access to whitelisted functions", function ()
			local code = "return os.time"
			assert.is_function(liluat.private.sandbox(code)())
		end)

		it("should accept custom whitelists", function ()
			local code = "return string and string.find"
			assert.is_nil(liluat.private.sandbox(code, nil, nil, {})())
		end)

		it("should handle compile errors and print its surrounding lines", function ()
			local code = [[
-- 1
-- 2
-- 3
-- 4
-- 5
-- 6
"a" .. nil
-- 8
-- 9
-- 10
-- 11
-- 12
-- 13]]

			local expected = [[
Syntax error in sandboxed code "code" in line 7:
.*
  4:  %-%- 4
  5:  %-%- 5
  6:  %-%- 6
  7:> "a" .. nil
  8:  %-%- 8
  9:  %-%- 9
 10:  %-%- 10]]

			local status, error_message = pcall(liluat.private.sandbox, code, "code")

			assert.is_false(status)
			assert.truthy(error_message:find(expected))
		end)
	end)

	describe("liluat.compile", function ()
		it("should not crash with two newlines and at least one character between two code blocks", function()
			local template = liluat.compile([[
{{}}

x{{}}
]])
		end)

		it("should not crash with tabs at the front either", function()
			local template = liluat.compile([[
	{{}}

	x{{}}
]])
		end)

		it("should compile templates into code", function ()
			local template = "a{{i = 0}}{{= i}}b"
			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("a")
i = 0
__liluat_output_function( i)
__liluat_output_function("b")]]
			}

			assert.same(expected_output, liluat.compile(template))
		end)

		it("should accept template names", function ()
			local template = "a"
			local template_name = "my template"
			local expected_output = {
				name = "my template",
				code = '__liluat_output_function("a")'
			}

			assert.same(expected_output, liluat.compile(template, nil, template_name))
		end)

		it("should accept other template tags passed as options", function ()
			local template = "a{{i = 0}}{{= i}}b"
			local options = {
				start_tag = "{{",
				end_tag = "}}"
			}
			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("a")
i = 0
__liluat_output_function( i)
__liluat_output_function("b")]]
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should trim all trailing newlines if told so", function ()
			local options = {
				trim_right = "all"
			}
			local template = [[
some text
{{for i = 1, 5 do}}
{{= i}}
{{end}}
{{ -- comment}}
some text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function( i)
end
 -- comment
__liluat_output_function("some text")]]
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should trim trailing newlines after expressions if told so", function ()
			local options = {
				trim_right = "expression"
			}
			local template = [[
some text
{{for i = 1, 5 do}}
{{= i}}
{{end}}
{{ -- comment}}
some text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function("\
")
__liluat_output_function( i)
end
__liluat_output_function("\
")
 -- comment
__liluat_output_function("\
some text")]]
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should trim trailing newlines after code if told so", function ()
			local options = {
				trim_right = "code"
			}
			local template = [[
some text
{{for i = 1, 5 do}}
{{= i}}
{{end}}
{{ -- comment}}
some text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function( i)
__liluat_output_function("\
")
end
 -- comment
__liluat_output_function("some text")]]
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("shouldn't trim newlines if told so", function ()
			local options = {
				trim_right = false
			}
			local template = [[
some text
{{for i = 1, 5 do}}
{{= i}}
{{end}}
{{ -- comment}}
some text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function("\
")
__liluat_output_function( i)
__liluat_output_function("\
")
end
__liluat_output_function("\
")
 -- comment
__liluat_output_function("\
some text")]]
			}

			assert.same(expected_output, liluat.compile(template, options))

		end)

		it("should trim all spaces in front of template blocks if told so", function ()
			local options = {
				trim_left = "all",
				trim_right = false
			}
			local template = [[
some text
 	{{for i = 1, 5 do}}

	{{= i}}
 {{end}}
some more text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function("\
\
")
__liluat_output_function( i)
__liluat_output_function("\
")
end
__liluat_output_function("\
some more text")]]
			}

			local output = liluat.compile(template, options)
			output.code = output.code:gsub("\\9", "\t") --make the test work across lua versions

			assert.same(expected_output, output)
		end)

		it("should trim all spaces in front of expressions if told so", function ()
			local options = {
				trim_left = "expression",
				trim_right = false
			}
			local template = [[
some text
 	{{for i = 1, 5 do}}
	{{= i}}
 {{end}}
some more text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
 	")
for i = 1, 5 do
__liluat_output_function("\
")
__liluat_output_function( i)
__liluat_output_function("\
 ")
end
__liluat_output_function("\
some more text")]]
			}

			local output = liluat.compile(template, options)
			output.code = output.code:gsub("\\9", "\t") --make the test work across lua versions

			assert.same(expected_output, output)
		end)

		it("should trim all spaces in front of code if told so", function ()
			local options = {
				trim_left = "code",
				trim_right = false
			}
			local template = [[
some text
 	{{for i = 1, 5 do}}
	{{= i}}
 {{end}}
some more text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
for i = 1, 5 do
__liluat_output_function("\
	")
__liluat_output_function( i)
__liluat_output_function("\
")
end
__liluat_output_function("\
some more text")]]
			}

			local output = liluat.compile(template, options)
			output.code = output.code:gsub("\\9", "\t") --make the test work across lua versions

			assert.same(expected_output, output)
		end)

		it("shouldn't trim spaces if told so", function ()
			local options = {
				trim_left = false,
				trim_right = false
			}
			local template = [[
some text
 	{{for i = 1, 5 do}}
	{{= i}}
 {{end}}
some more text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
 	")
for i = 1, 5 do
__liluat_output_function("\
	")
__liluat_output_function( i)
__liluat_output_function("\
 ")
end
__liluat_output_function("\
some more text")]]
			}

			local output = liluat.compile(template, options)
			output.code = output.code:gsub("\\9", "\t") --make the test work across lua versions


			assert.same(expected_output, output)
		end)

		it("should trim both spaces and trailing newlines if told so", function ()
			local options = {
				trim_left = "all",
				trim_right = "all"
			}

			local template = [[
some text
 {{= 1}}
 {{= 2}}
{{= 3}}

{{= 4}}
{{= 5}} 

{{= 6}} 
{{= 7}} 
	{{= 8}}
more text]]

			local expected_output = {
				name = "liluat.compile",
				code = [[
__liluat_output_function("some text\
")
__liluat_output_function( 1)
__liluat_output_function( 2)
__liluat_output_function( 3)
__liluat_output_function("\
")
__liluat_output_function( 4)
__liluat_output_function( 5)
__liluat_output_function(" \
\
")
__liluat_output_function( 6)
__liluat_output_function(" \
")
__liluat_output_function( 7)
__liluat_output_function(" \
")
__liluat_output_function( 8)
__liluat_output_function("more text")]]
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should trim left in the first line", function ()
			local template = "\t{{code}}"

			local options = {
				trim_left = "all"
			}

			local expected_output = {
				name = "liluat.compile",
				code = "code"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_left (force trim)", function ()
			local template = "\t{{-code}}"

			local expected_output = {
				code = "code",
				name = "liluat.compile"
			}

			local options = {
				trim_left = false
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_left (force no trim)", function()
			local template = "  {{+code}}"

			local expected_output = {
				code = '__liluat_output_function("  ")\ncode',
				name = "liluat.compile"
			}

			local options = {
				trim_left = "all"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_right (force trim)", function ()
			local template = "{{code-}}\n"

			local options = {
				trim_left = false
			}

			local expected_output =  {
				code = "code",
				name = "liluat.compile"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_right (force no trim)", function ()
			local template = "{{code+}}\n"

			local options = {
				trim_left = "all"
			}

			local expected_output =  {
				code = 'code\n__liluat_output_function("\\\n")',
				name = "liluat.compile"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_left and trim_right (force trim)", function ()
			local template = "  {{-code-}}\n"

			local options = {
				trim_left = false,
				trim_right = false
			}

			local expected_output = {
				code = 'code',
				name = "liluat.compile"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)

		it("should locally override trim_left and trim_right (force no trim)", function ()
			local template = "  {{+code+}}\n"

			local options = {
				trim_left = "all",
				trim_right = "all"
			}

			local expected_output = {
				code = '__liluat_output_function("  ")\ncode\n__liluat_output_function("\\\n")',
				name = "liluat.compile"
			}

			assert.same(expected_output, liluat.compile(template, options))
		end)
	end)

	describe("liluat.compile_file", function ()
		it("should load a template file", function ()
			local template_path = "spec/index.html.template"
			local expected_output = loadfile("spec/index.html.template.lua")()

			assert.same(expected_output, liluat.compile_file(template_path))
		end)

		it("should accept different tags via the options", function ()
			local template_path = "spec/jinja.template"
			local options = {
				start_tag = "{%",
				end_tag = "%}"
			}
			local expected_output = loadfile("spec/jinja.template.lua")()

			assert.same(expected_output, liluat.compile_file(template_path, options))
		end)
	end)

	describe("get_dependencies", function ()
		it("should list all includes", function ()
			local template = '{{include: "spec/index.html.template"}}'
			local expected_output = {
				"spec/index.html.template",
				"spec/content.html.template"
			}

			assert.same(expected_output, liluat.get_dependencies(template))
		end)

		it("should list every file only once", function ()
			local template = '{{include: "spec/index.html.template"}}{{include: "spec/index.html.template"}}'
			local expected_output = {
				"spec/index.html.template",
				"spec/content.html.template"
			}

			assert.same(expected_output, liluat.get_dependencies(template))
		end)
	end)

	describe("liluat.inline", function ()
		it("should inline a template", function ()
			local template = liluat.private.read_entire_file("spec/index.html.template")
			local expected_output = liluat.private.read_entire_file("spec/index.html.template.inlined")

			assert.equal(expected_output, liluat.inline(template, nil, "spec/"))
		end)
	end)

	describe("sandbox", function ()
		it("should run code in a sandbox", function ()
			local code = "return i, 1"
			local i = 1
			local a, b = liluat.private.sandbox(code)()

			assert.is_nil(a)
			assert.equal(1, b)
		end)

		it("should pass an environment", function ()
			local code = "return i"
			assert.equal(1, liluat.private.sandbox(code, nil, {i = 1})())
		end)

		it("should not have access to non-whitelisted functions", function ()
			local code = "return load"
			assert.is_nil(liluat.private.sandbox(code)())
		end)

		it("should have access to whitelisted functions", function ()
			local code = "return os.time"
			assert.is_function(liluat.private.sandbox(code)())
		end)
	end)

	describe("add_include_and_detect_cycles", function ()
		it("should add includes", function ()
			local include_list = {}

			liluat.private.add_include_and_detect_cycles(include_list, "a")
			liluat.private.add_include_and_detect_cycles(include_list.a, "b")
			liluat.private.add_include_and_detect_cycles(include_list.a.b, "c")
			liluat.private.add_include_and_detect_cycles(include_list, "d")

			assert.is_nil(include_list[0])
			assert.equal(include_list, include_list.a[0])
			assert.is_table(include_list.a)
			assert.equal(include_list.a, include_list.a.b[0])
			assert.is_table(include_list.a.b)
			assert.equal(include_list.a.b, include_list.a.b.c[0])
			assert.is_table(include_list.a.b.c)
			assert.is_equal(include_list, include_list.d[0])
			assert.is_table(include_list.d)
		end)

		it("should detect inclusion cycles", function ()
			local include_list = {}

			liluat.private.add_include_and_detect_cycles(include_list, "a")
			liluat.private.add_include_and_detect_cycles(include_list.a, "b")
			assert.has_error(
				function ()
					liluat.private.add_include_and_detect_cycles(include_list.a.b, "a")
				end,
				"Cyclic inclusion detected")
		end)
	end)

	describe("dirname", function ()
		it("should return the directory containing a file", function ()
			assert.equal("/home/user/", liluat.private.dirname("/home/user/.bashrc"))
			assert.equal("/home/user/", liluat.private.dirname("/home/user/"))
			assert.equal("/home/", liluat.private.dirname("/home/user"))
			assert.equal("./", liluat.private.dirname("./template"))
			assert.equal("", liluat.private.dirname("."))
		end)
	end)

	describe("version", function ()
		it("should return the current version number", function ()
			assert.equal("1.2.0", liluat.version())
		end)
	end)

	describe("liluat.render", function ()
		it("should handle runtime errors and print its surrounding lines", function ()
			local code = [[
-- 1
-- 2
-- 3
-- 4
-- 5
-- 6
local test = "a" .. nil
-- 8
-- 9
-- 10
-- 11
-- 12
-- 13]]

			local expected = [[
Runtime error in sandboxed code "code" in line 7:
.*
  4:  %-%- 4
  5:  %-%- 5
  6:  %-%- 6
  7:> local test = "a" .. nil
  8:  %-%- 8
  9:  %-%- 9
 10:  %-%- 10]]

			local status, error_message = pcall(liluat.render, {name = 'code', code = code})

			assert.is_false(status)
			assert.truthy(error_message:find(expected))
		end)

		it("should accept the 'reference' option", function ()
			local template = "{{= tostring(table_reference)}}"
			local parameters = {table_reference = {}}

			local code = liluat.compile(template)

			assert.equal(tostring(parameters.table_reference), liluat.render(code, parameters, {reference = true}))
		end)
	end)

	describe("liluat.render_coroutine", function ()
		it("should accept the 'reference' option", function ()
			local template = "{{= tostring(table_reference)}}"
			local parameters = {table_reference = {}}

			local code = liluat.compile(template)

			local thread = coroutine.wrap(liluat.render_coroutine(code, parameters, {reference = true}))

			local rendered_string = thread()

			assert.equal(tostring(parameters.table_reference), rendered_string)
		end)
	end)
end)
