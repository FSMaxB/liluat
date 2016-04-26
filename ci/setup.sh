#!/bin/bash
# A script for setting up environment for travis-ci testing.
# Sets up Lua and Luarocks.
# LUA must be "Lua5.1", "Lua5.2", "Lua5.3", "LuaJIT2.0" or "LuaJIT2.1".
#
# This file is based on work by Olivine Labs, LLC.
# See https://github.com/Olivine-Labs/busted/.travis_setup.sh

set -e

mkdir "$HOME/prefix"
export PATH="$HOME/prefix/bin:$PATH"

if [ "$LUA" == "LuaJIT2.0" ]; then
	wget -O - https://github.com/LuaJIT/LuaJIT/archive/v2.0.4.tar.gz | tar xz
	cd LuaJIT-2.0.4
	make && make install INSTALL_TSYMNAME=lua PREFIX="$HOME/prefix/"
elif [ "$LUA" == "LuaJIT2.1" ]; then
	wget -O - https://github.com/LuaJIT/LuaJIT/archive/v2.1.0-beta2.tar.gz | tar xz
	cd LuaJIT-2.1.0-beta2
	make && make install INSTALL_TSYMNAME=lua PREFIX="$HOME/prefix/"
	ln -sf luajit-2.1.0-beta2 "$HOME/prefix/bin/lua"
	ln -sf luajit-2.1 "$HOME/prefix/include/lua5.1"
else
	if [ "$LUA" == "Lua5.1" ]; then
		wget -O - http://www.lua.org/ftp/lua-5.1.5.tar.gz | tar xz
		cd lua-5.1.5;
	elif [ "$LUA" == "Lua5.2" ]; then
	wget -O - http://www.lua.org/ftp/lua-5.2.4.tar.gz | tar xz
		cd lua-5.2.4;
	elif [ "$LUA" == "Lua5.3" ]; then
		wget -O - http://www.lua.org/ftp/lua-5.3.2.tar.gz | tar xz
		cd lua-5.3.2;
	fi
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		make linux
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		make macosx
	elif [[ "$OSTYPE" == "freebsd"* ]]; then
		make freebsd
	else
		make generic
	fi
	make install INSTALL_TOP="$HOME/prefix"
fi

cd ..
wget -O - http://luarocks.org/releases/luarocks-2.3.0.tar.gz | tar xz || wget -O - http://keplerproject.github.io/luarocks/releases/luarocks-2.3.0.tar.gz | tar xz
cd luarocks-2.3.0

if [ "$LUA" == "LuaJIT2.0" ]; then
	./configure --with-lua-include="$HOME/prefix/include/luajit-2.0/" --prefix="$HOME/prefix/";
else
	./configure --with-lua-include="$HOME/prefix/include/" --prefix="$HOME/prefix/";
fi

make build && make install
cd ..
