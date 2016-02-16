#!/usr/bin/env lua

local liluat = require('liluat')

if #arg > 1 then
	print('Usage: liluatpp.lua filename')
	os.exit(1)
end

local content

if #arg == 1 then
	local fin = assert(io.open(arg[1]))
	content = fin:read('*a')
	fin:close()
else
	content = io.read('*a')
end

io.write(liluat.precompile(content))
