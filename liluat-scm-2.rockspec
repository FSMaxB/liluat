package = "liluat"
version = "scm-2"

source = {
  url = "git://github.com/FSMaxB/liluat",
}

description = {
  summary = "Lightweight Lua based template engine.",
  detailed = "Liluat is a lightweight Lua based template engine. While simple to use it's still powerfull because you can embed arbitrary Lua code in templates. It doesn't need external dependencies other than Lua itself.",
  homepage = "https://github.com/FSMaxB/liluat",
  license = "MIT <http://opensource.org/licenses/MIT>"
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = "builtin",
  modules = {
    liluat = "liluat.lua"
  },
  install = {
    bin = {
      runliluat = "runliluat.lua"
    }
  }
}
