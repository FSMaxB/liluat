package = "liluat"
version = "scm-1"

source = {
  url = "git://github.com/FSMaxB/liluat",
}

description = {
  summary = "Lightweight Lua Template engine.",
  detailed = "liluat is a Lua template processor. Similar to php or jsp, you can embed lua code directly",
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
