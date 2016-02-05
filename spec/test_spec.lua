local liluat = require("liluat")

describe("liluat", function ()
	it("should return an empty string for empty templates", function ()
		assert.equal("", liluat.render(liluat.loadstring(""), {}))
	end)

	it("should render some example template", function ()
		local tmpl = liluat.loadstring([[<span>
#{ if user ~= nil then }#
Hello, #{= escapeHTML(user.name) }#!
#{ else }#
<a href="/login">login</a>
#{ end }#
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
#{= expression}# bla #{code}#
 #{other code}# some text
#{more code}##{}#
some more text]]
			local result = {}

			for chunk in liluat.private.all_chunks(template, "#{", "}#") do
				table.insert(result, chunk)
			end

			local expected_output = {
				"#{= expression}#",
				" bla ",
				"#{code}#",
				"\n ",
				"#{other code}#",
				" some text\n",
				"#{more code}#",
				"#{}#",
				"\nsome more text"
			}

			assert.same(expected_output, result)
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

	describe("liluat.lex", function ()
		it("should create a list of chunks", function ()
			local template = [[
#{= expression}# bla #{code}#
 #{other code}# some text
#{more code}##{}#
some more text]]

			local expected_output = {
				"#{= expression}#",
				" bla ",
				"#{code}#",
				"\n ",
				"#{other code}#",
				" some text\n",
				"#{more code}#",
				"#{}#",
				"\nsome more text"
			}

			assert.same(expected_output, liluat.lex(template, "#{", "}#"))
		end)

		it("should include files", function ()
			local template = [[
first line
#{include: "spec/read_entire_file-test"}#
another line]]

			local expected_output = {
				"first line\n",
				"This should be read by the 'read_entire_file' helper functions.\n",
				"\nanother line"
			}

			assert.same(expected_output, liluat.lex(template, "#{", "}#"))
		end)

		it("should work with other start and end tags", function ()
			local template = "text {%--template%} more text"
			local expected_output = {
				"text ",
				"{%--template%}",
				" more text"
			}

			assert.same(expected_output, liluat.lex(template, "{%", "%}"))
		end)

		it("should use existing table if specified", function ()
			local template = "bla {{= 5}} more bla"
			local output = {}
			local expected_output = {
				"bla ",
				"{{= 5}}",
				" more bla"
			}

			local result = liluat.lex(template, "{{", "}}", output)

			assert.equal(output, result)
			assert.same(expected_output, result)
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
	end)

	describe("liluat.loadstring", function ()
		it("should compile templates into code", function ()
			local template = "a#{i = 0}##{= i}#b"
			local expected_output = {
				name = "=(liluat.loadstring)",
				code = [[
coroutine.yield("a")
i = 0
coroutine.yield( i)
coroutine.yield("b")]]
			}

			assert.same(expected_output, liluat.loadstring(template))
		end)

		it("should accept template names", function ()
			local template = "a"
			local template_name = "my template"
			local expected_output = {
				name = "my template",
				code = 'coroutine.yield("a")'
			}

			assert.same(expected_output, liluat.loadstring(template, template_name))
		end)

		it("should accept other template tags passed as options", function ()
			local template = "a{{i = 0}}{{= i}}b"
			local options = {
				start_tag = "{{",
				end_tag = "}}"
			}
			local expected_output = {
				name = "=(liluat.loadstring)",
				code = [[
coroutine.yield("a")
i = 0
coroutine.yield( i)
coroutine.yield("b")]]
			}

			assert.same(expected_output, liluat.loadstring(template, nil, options))
		end)
	end)

	describe("liluat.loadfile", function ()
		it("should load a template file", function ()
			local template_path = "spec/index.html.template"
			local expected_output = loadfile("spec/index.html.template.lua")()

			assert.same(expected_output, liluat.loadfile(template_path))
		end)
	end)
end)
