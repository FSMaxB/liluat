local liluat = require('liluat')

local user = {
	name = '<world>'
}

function escapeHTML(str)
	local tt = {
		['&'] = '&amp;',
		['<'] = '&lt;',
		['>'] = '&gt;',
		['"'] = '&quot;',
		["'"] = '&#39;',
	}
	local r = string.gsub(str, '[&<>"\']', tt)
	return r
end

local tmpl = liluat.loadstring([[<span>
#{ if user ~= nil then }#
Hello, #{= escapeHTML(user.name) }#!
#{ else }#
<a href="/login">login</a>
#{ end }#
</span>
]])

io.write(liluat.render(tmpl, {user = user}))
