#!/bin/bash
export PATH="$HOME/prefix/bin/:$PATH"

eval $(luarocks path --bin)

luarocks install --local luasec
luarocks install --local busted
