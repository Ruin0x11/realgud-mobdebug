#!/bin/sh

# MOBDEBUG_PATH=~/opt/MobDebug/src/?.lua

eval "`luarocks path`"
PWD=$(dirname $2)
export LUA_PATH="$PWD/?.lua;$PWD/thirdparty/?.lua;$MOBDEBUG_PATH;$LUA_PATH"

if [[ $(basename -- "$2") == "main.lua" ]]; then
    eval "$1 $(dirname $2) -debug" &
else
    eval "$1 $2 -debug" &
fi

luajit -e "require('mobdebug').listen()"
