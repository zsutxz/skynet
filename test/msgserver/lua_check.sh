#!/bin/bash
SCRIPT_DIR=$(cd `dirname $0`; pwd)
LK_LUA_CHECK=~/tmp/luacheckdir
LK_SKYNET_NAME="skynet-1.0.0"
LK_LUA_GOLBALS="class table bit_set bit_test checknumber checkbool checktable checkint math _tostring string \
				printf isset require os SERVICE_NAME create_roulette_by_config create_roulette_by_config_cfgkey\
				pcall xpcall"

cd ${SCRIPT_DIR}
if [ ! -d ${LK_LUA_CHECK} ]; then	
	mkdir -p ${LK_LUA_CHECK}
	if [ $? -ne 0 ]; then
		echo "[error] init luacheck fail!"
		exit
	fi
	if [ -f lkctl_plugin.tar ]; then
		tar -zxf lkctl_plugin.tar -C ${LK_LUA_CHECK}
		if [ $? -ne 0 ]; then
			echo "[error] lua_check extract fail!"
			exit
		fi
		echo "[info] lua_check init for the first time, please wait"
		make linux -C ${LK_LUA_CHECK}/lua > /dev/null
		echo "[info] lua_check init ok!"
	else
		echo "[error] lua_check plugin not found!"
		exit
	fi
fi

cd ../server-skynet/bin

LuaExec=${LK_LUA_CHECK}/lua/lua
if [ ! -f ${LuaExec} ]; then
	echo "[error] lua not found! "
	exit
fi

echo 'require "luacheck.main"' > ${LK_LUA_CHECK}/checklua.lua

Args="$1"
if [ "$Args" != "" ]; then
	for file in `ls`
	do 
		case "$file" in
			"3rd" | ${LK_SKYNET_NAME} | "Makefile" | "client" | ".svn" ) ;;
			*)
				Luas=`find $file -regex "[a-zA-Z0-9\/\._-]+\.lua" ! -path "*/tests/*" -name $Args`
				# filter special filename, it would cause script stop
				if [ "$Luas" != "" ]; then
					${LuaExec} -e "package.path=[[${LK_LUA_CHECK}/?.lua;${LK_LUA_CHECK}/?/init.lua;]]..package.path" "${LK_LUA_CHECK}/checklua.lua" $Luas \
						--no-color --globals ${LK_LUA_GOLBALS}
				fi ;;
		esac
	done
else
	for file in `ls`
	do 
		case "$file" in
			"3rd" | ${LK_SKYNET_NAME} | "Makefile" | "client") ;;
			*)
				Luas=`find $file -regex "[a-zA-Z0-9\/\._-]+\.lua" ! -path "*/tests/*"`
				# filter special filename, it would cause script stop
				if [ "$Luas" != "" ]; then
					${LuaExec} -e "package.path=[[${LK_LUA_CHECK}/?.lua;${LK_LUA_CHECK}/?/init.lua;]]..package.path" "${LK_LUA_CHECK}/checklua.lua" $Luas \
						--no-unused --quiet --no-unused-args --no-unused-secondaries --no-redefined --no-color --globals ${LK_LUA_GOLBALS} \
						--ignore 542 512
				fi ;;
		esac
	done
fi

echo "[info] lua check finish!"
