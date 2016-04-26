# liluat

[![Travis Build Status](https://travis-ci.org/FSMaxB/liluat.svg?branch=master)](https://travis-ci.org/FSMaxB/liluat)

Liluat is a lightweight Lua based template engine. While simple to use it's still powerfull because you can embed arbitrary Lua code in templates. It doesn't need external dependencies other than Lua itself.

Liluat is a fork of version 1.0 of [slt2](https://github.com/henix/slt2) by henix. Although the core concept was taken from slt2, the code has been almost completely rewritten.

## Table of contents
1. [OS support](#os-support)
2. [Lua support](#lua-support)
3. [Installation](#installation)
4. [Basic Syntax](#basic-syntax)
5. [Example](#example)
6. [API](#api)
7. [Trimming](#trimming)
8. [Options](#options)
9. [Command line utility](#command-line-utility)
10. [Sandboxing](#sandboxing)
11. [Caveats](#caveats)
12. [License](#license)
13. [Contributing](#contributing)

## OS support
Liluat is developed on GNU/Linux and automatically tested on GNU/Linux and Mac OS X. I have much confidence that it will also work on FreeBSD, other BSDs and on other POSIX compatible systems like e.g. Cygwin.

Windows was not tested, but it might work with some limitations:
* absolute paths in template includes won't be properly detected because they don't start with a `/`
* `\` is not supported as path separator
* template files with Windows style line endings (`"\r\n"`) aren't supported
* the unit tests for the command line won't work because they rely on a POSIX shell being available

## Lua support
Liluat is automatically tested on the following Lua implementations:

* Lua 5.1
* Lua 5.2
* Lua 5.3
* LuaJIT 2.0
* LuaJIT 2.1 (beta)

## Installation
Lua is available via [luarocks](https://luarocks.org), the following command installs it via luarocks:
```
# luarocks install liluat
```
You might need to add `--local` if you don't have admin (root) privileges.

Alternatively just copy the file `liluat.lua` to your software (this won't install the command line interface though).

## Basic syntax
There are three different types of template blocks:

### Code
You can write arbitrary Lua code in the form:
```
{{ some code }}
```
This allows for writing simple loops and conditions or even more complex logic.
### Expressions
You can write arbitrary Lua expression that can be converted into a string like this:
```
{{= expression}}
```
### Includes
You can include other template files like this:
```
{{include: 'templates/file_name'}}
```
By default the include path is either relative to the directory where the template that does the include is in or it is an absolute path starting with a `/`, e.g. `'/tmp/template-dfjCm'`. You can change this behavior using the `base_path` option, see [Options](#options).

Liluat is able to detect cyclic inclusion in most cases (eg. not if you used symlinks to create a cycle in the filesystem). 

### More
There is more to the syntax of liluat, but that will be explained later on in the section [Trimming](#trimming).

## Example
Some basic template in action.

See `example.lua`:
```lua
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
```

Output:
```html
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
```

## API

### liluat.compile(template, [options], [template\_name], [start\_path])
Compile the template into Lua code that can later be rendered. Returns a compiled template.
* `template`: The template to compile
* `options`: A table containing different configuration options, see the [Options](#options) section.
* `template_name`: A name to identify the template with. This is especially useful to be able to find out where a Lua syntax or runtime error is coming from.
* `start_path`: Path to start in as a working directory. If the `base_path` option is not set, this is the path to which the first inclusion is relative to.

### liluat.compile\_file(filename, [options])
Same as `liluat.compile` but loads the template from a file. `template_name` is set to the filename and `start_path` is set to the path where the file is in. Returns a compiled template.
* `filename`: File to load the template from.
* `options`: A table containing different configuration options, see the [Options](#options) section.

### liluat.render(compiled\_template, [values], [options])
Render a compiled template into a string, using the given values. This runs the compiled template in a sandbox with `values` added to it's environment.
* `compiled_template`: This is the output of `liluat.compile`. Essentially Lua code with some meta data.
* `values`: A Lua table containing any kind of values. This can even be functions or custom data types from C. These values are accessible inside the template.
* `options`: A table containing different configuration options, see the [Options](#options) section. NOTE: Most of those options only change the behavior of `liluat.compile`.

### liluat.render\_coroutine(compiled\_template, [values], [options])
Same as `liluat.render` but returns a function that can be run in a coroutine and will return one chunk of data at a time (so you can kind of "stream" the template rendering).

### liluat.inline(template, [options], [start\_path])
Load a template and return a template string where all the included templates have been inlined.
* `template`: A template string to be inlined.
* `options`: A table containing different configuration options, see the [Options](#options) section.
* `start_path`: Path to start in as a working directory. If the `base_path` option is not set, this is the path to which the first inclusion is relative to.

### liluat.get\_dependencies(template, [options], [start\_path])
Get a table containing all of the files that a template includes (also recursively).
* `template`: The template to examine.
* `options`: A table containing different configuration options, see the [Options] section.
* `start_path`: Path to start in as a working directory. If the `base_path` option is not set, this is the path to which the first inclusion is relative to.

## Trimming
An important feature not yet talked about is trimming. In order to be able to write templates that look nice and readable while still keeping the output nice, some kinds of whitespaces need to be trimmed in some cases.

There are two kinds of trimming that liluat supports:

### Left trimming
In case a line contains only whitespaces in front of a template block, those are removed when left trimming is enabled.

### Right trimming
Right trimming, if enabled, removes newline characters directly following a template block.

### Settings
The trimming can be globally enabled and disabled via the `trim_left` and `trim_right` options. Possible values are:
* `"all"`: trim all template blocks
* `"expression"`: trim only expression blocks
* `"code"`: trim only code blocks, this is the default
* `false`: disable trimming

Include blocks are not trimmed.

### Local override
You can locally override left and right trimming via `+` and `-`, where `+` means, no trimming, and `-` means trimming. For example, the block `{{+ code -}}` will be trimmed right, but not left, no matter what the global trimming settings are.

### Example
In this example, `trim_left` and `trim_right` are set to `"code"`, which is the default.

```
	{{for i = 1, 4 do}}
		{{= i}}
	{{end}}
	{{for i = 5, 8 do}}
		{{-= i-}}
	{{end}}
	{{for i = 9, 12 do+}}
		{{-= i}}
	{{end}}
```

Output:
```
		1
		2
		3
		4
5678
9

10

11

12
```

## Options
The following options can be passed via the `options` table:
* `start_tag`: Start tag to be used instead of `{{`
* `end_tag`: End tag to be used instead of `}}`
* `trim_right`: one of `"all"`, `"code"`, `"expression"` or `false` to disable. Default is `"code"`. See the section [Trimming](#trimming) for more information.
* `trim_left`: one of `"all"`, `"code"`, `"expression"` or `false` to disable. Default is `"code"`. See the section [Trimming](#trimming) for more information.
* `base_path`: Path that is used as base path for includes. If `nil` or `false`, all include paths are interpreted relative to the files path itself. Not that this doesn't influence absolute paths.
* `reference`: If set to `true`, `liluat.render` will reference the environment in the sandbox instead of recursively copyiing it. This reduces part of the security of the sandbox, because values can now leak out of it. However, this option is useful if you pass in environments that use a lot of memory or contain reference cycles, see [Caveats/Environment is copied](#environment-is-copied).

## Command line utility
Liluat comes with a command line interface:

```
$ runliluat --help
Usage: runliluat [options]
Options:
	-h|--help
		Show this message.
	--values lua_table
		Table containing values to use in the template.
	--value-file file_name
		Use a file to define the table of values to use in the template.
	-t|--template-file file_name
		File that contains the template
	-n|--name template_name
		Name to use for the template
	-d|--dependencies
		List the dependencies of the template (list of included files)
	-i|--inline
		Inline all the included files into one template.
	-o|--output filename
		File to write the output to (defaults to stdout)
	--options lua_table
		A table of options for liluat
	--options-file file_name
		Read the options from a file.
	--stdin "template"
		Get the template from stdin.
	--stdin "values"
		Get the table of values from stdin.
	--stdin "options"
		Get the options from stdin.
	-v|--version
		Print the current version.
	--path path
		Root path of the templates.
```

## Sandboxing
All the code in the templates is run in a sandbox. To achieve this, the code is run with its own global environment, Lua bytecode is forbidden and only a subset of Lua's standard library functions is allowed via a whitelist. If you require additional standard library functions, you have to pass them in manually via the `values` parameter.

The whitelist currently contains the following:
```
ipairs
next
pairs
rawequal
rawget
rawset
select
tonumber
tostring
type
unpack
string
table
math
os.date
os.difftime
os.time
coroutine
```

## Caveats
This section documents known issues that can arise in certain usage scenarios.

### Environment is copied
Due to the sandboxing, the entire environment passed into `liluat.render` or `liluat.render_coroutine` is recursively copied. This can have the following consequences (and probably more):

* High memory usage if the environment uses a large amount of memory. Because a copy is created, liluat needs the same amount once again for the copy. This can get even worse when you render multiple templates with a big environment, because Lua's incremental garbage collector might not be fast enough to clean it up right away.
* Environments that contain reference cycles will trigger an infinite loop that results in a stack overflow.
* All metatables are removed from the values in the sandbox. This also means that most object oriented modules will break if you add them to the environment.

All those above issues can be fixed by setting the `reference` option to `true`, see [Options](#options). Note though that this will decrease the security of the sandbox, because changes to the environment that happen in the sandbox will leave the sandbox.

## License
Liluat is free software licensed under the MIT license:

> liluat - Lightweight Lua Template engine
>
> Project page: https://github.com/FSMaxB/liluat
>
> liluat is based on slt2 by henix, see https://github.com/henix/slt2
>
> Copyright © 2016 Max Bruckner
> Copyright © 2011-2016 henix
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Contributing
If you find a bug or have a suggestion on what could be improved, write an issue on GitHub or write me an email.

I will also gladly accept pull requests via GitHub or email if I think that it will benefit the library. Be sure to talk to me first to increase your success rate and prevent possible frustration/misunderstandings.

### Coding style
* use tabs for indentation
* don't leave trailing spaces

Other than that: Take a look at what's already there and try to adapt.

### Unit tests
Write unit tests for everything you do. I'm using the [busted](http://olivinelabs.com/busted/) unit testing framework. **Every commit** needs to pass the tests on every supported Lua implementation. Note that pull requests get automatically tested on Travis-CI.
