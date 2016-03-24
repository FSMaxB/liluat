#!/usr/bin/env lua

-- preload to make sure that 'require' loads the local liluat and not the globally installed one
package.loaded["liluat"] = loadfile("liluat.lua")()

-- now load 'runliluat'
dofile("runliluat.lua")
