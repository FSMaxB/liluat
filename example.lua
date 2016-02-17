#!/usr/bin/env lua
local liluat = require("liluat")

local template = [[
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="UTF-8">
		<title>{{= title}}</title>
	</head>
	<body>
		<h1>Vegetables</h1>
		<ul>
		{{ -- write regular lua code in the template}}
		{{for _,vegetable in ipairs(vegetables) do}}
			<li><b>{{= vegetable}}</b></li>
		{{end}}
		</ul>
	</body>
</html>
]]

-- values to render the template with
local values = {
	title = "A fine selection of vegetables.",
	vegetables = {
		"carrot",
		"cucumber",
		"broccoli",
		"tomato"
	}
}

-- compile the template into lua code
local compiled_template = liluat.compile(template)

local rendered_template = liluat.render(compiled_template, values)

io.write(rendered_template)
--[[ output:
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="UTF-8">
		<title>A fine selection of vegetables.</title>
	</head>
	<body>
		<h1>Vegetables</h1>
		<ul>
			<li><b>carrot</b></li>
			<li><b>cucumber</b></li>
			<li><b>broccoli</b></li>
			<li><b>tomato</b></li>
		</ul>
	</body>
</html>
--]]
