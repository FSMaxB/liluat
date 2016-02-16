# liluat

[![Travis Build Status](https://travis-ci.org/FSMaxB/liluat.svg?branch=master)](https://travis-ci.org/FSMaxB/liluat)

liluat is a Lua template processor. Similar to php or jsp, you can embed lua code directly.

## Installation

```
luarocks install liluat
```

## Example

see test.lua

```lua
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
```

## Template Syntax

* #{ lua code }# : embed lua code
* #{= expression }# : embed lua expression
* #{include: 'file' }# : include another template

NOTE: don't specify a cyclic inclusion

## API Reference

### liluat.loadstring(template, start\_tag, end\_tag, tmpl\_name)
### liluat.loadfile(filename, start\_tag, end\_tag)

"Compile" the template from a string or a file, return compiled object.

* start_tag: default "#{"
* end_tag: default "}#"

### liluat.render\_co(f, env)

Return a coroutine function which yields a chunk of result every time. You can `coroutine.create` or `coroutine.wrap` on it.

### liluat.render(f, env)

Return render result as a string.

## Standalone commands

* runliluat.lua : render a template with a lua table value
* liluatpp.lua : preprocess a template (inline included files)
* liluatdep.lua : output dependencies of a template file (the included files, like -MD option of gcc)

To install, create a symbolic link to them in your path.

## Compatibility

liluat has been tested on:

* Lua 5.1
* Lua 5.2
* Lua 5.3
* luajit 2.0

Other versions of Lua are not tested.

## License

MIT License

## Contribute

Please create an issue, explaining what's the problem you are trying to solve, before you send a pull request.
