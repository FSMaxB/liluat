#!/bin/bash
export PATH="$HOME/prefix/bin/:$PATH"

eval $(luarocks path --bin)

busted
