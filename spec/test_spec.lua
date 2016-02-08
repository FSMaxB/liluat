local slt2 = require("slt2")

describe("slt2", function ()
	it("should return an empty string for empty templates", function ()
		assert.equal("", slt2.render(slt2.loadstring(""), {}))
	end)

	it("should render some example template", function ()
		local tmpl = slt2.loadstring([[<span>
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

		assert.equal(expected_output, slt2.render(tmpl, {user = {name = "<world>"}, escapeHTML = escapeHTML }))
	end)
end)
