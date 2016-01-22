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

	describe("escape_pattern", function ()
		it("should escape lua pattern special characters", function ()
			local input = ".%a%c%d%l%p%s%u%w%x%z().%%+-*?[]^$"
			local expected_output = "%.%%a%%c%%d%%l%%p%%s%%u%%w%%x%%z%(%)%.%%%%%+%-%*%?%[%]%^%$"
			local escaped_pattern = liluat.private.escape_pattern(input)

			assert.equals(expected_output, escaped_pattern)
			assert.truthy(input:find(escaped_pattern))
		end)
	end)
end)
