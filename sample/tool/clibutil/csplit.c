#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <string.h>

//编译: gcc -shared -o csplit.so -fPIC -std=c99 csplit.c -O2 -Wall
//基于源字符串，时间复杂度O(n)，空间复杂度O(1)
int split(lua_State * L)
{
	size_t len=0;
	const char* src = lua_tolstring(L,1, &len);
	char pt = lua_tostring(L, 2)[0];
	int begpos = 0,endpos = len-1;

	//去掉头
	for(;begpos<=endpos;++begpos){
		if(src[begpos]!=pt)
			break;
	}
	//去掉尾巴
	for(;endpos>=begpos;--endpos){
		if(src[endpos]!=pt)
			break;
	}

	int n=0,pos = begpos;
	for(int i=begpos;i<=endpos;++i){
		if(src[i]==pt){
			lua_pushlstring(L, src+pos, i-pos);
			++n;	//返回数量加一

			while(src[i] == pt && i<=endpos)
				++i;
			pos = i;
		}
	}
	if(pos <= endpos){
		lua_pushlstring(L, src+pos, endpos-pos+1);
		++n;
	}

	return n;
}

int split_to_table(lua_State * L)
{
	size_t len=0;
	const char* src = lua_tolstring(L,1, &len);
	char pt = lua_tostring(L, 2)[0];
	int begpos = 0,endpos = len-1;

	//去掉头
	for(;begpos<=endpos;++begpos){
		if(src[begpos]!=pt)
			break;
	}
	//去掉尾巴
	for(;endpos>=begpos;--endpos){
		if(src[endpos]!=pt)
			break;
	}

	int n=0,pos = begpos;
	lua_newtable(L);
	for(int i=begpos;i<=endpos;++i){
		if(src[i]==pt){
			++n;	//返回数量加一
			lua_pushnumber(L,n);
			lua_pushlstring(L, src+pos, i-pos);
			lua_settable(L,-3);

			while(src[i] == pt && i<=endpos)
				++i;
			pos = i;
		}
	}
	if(pos <= endpos){
		++n;
		lua_pushnumber(L,n);
		lua_pushlstring(L, src+pos, endpos-pos+1);
		lua_settable(L,-3);
	}

	return 1;
}

int splitsql(lua_State * L)
{
	size_t len=0;
	const char* src = lua_tolstring(L,1, &len);
	char pt=' ',pt1='.',pt2=';',pt3='=';
	int begpos = 0,endpos = len-1;

	//去掉头
	for(;begpos<=endpos;++begpos){
		if(src[begpos]!=pt)
			break;
	}
	//去掉尾巴
	for(;endpos>=begpos;--endpos){
		if(src[endpos]!=pt)
			break;
	}
	int n=0,pos = begpos;
	lua_newtable(L);
	for(int i=begpos;i<=endpos;++i){
		if(src[i]==pt){
			++n;	//返回数量加一
			lua_pushnumber(L,n);
			lua_pushlstring(L, src+pos, i-pos);
			lua_settable(L,-3);

			while(src[i] == pt && i<=endpos)
				++i;
			pos = i;
		}
		else if(src[i]==pt1 || src[i] == pt2 || src[i] == pt3)
		{
			++n;	//返回数量加一
			lua_pushnumber(L,n);
			lua_pushlstring(L, src+pos, i-pos);
			lua_settable(L,-3);

			//pt 本身也push进去
			++n;
			lua_pushnumber(L,n);
			lua_pushlstring(L, src+i, 1);
			lua_settable(L,-3);
			
			++i;
			while(src[i] == pt && i<=endpos)
				++i;
			pos = i;

		}
	}
	if(pos <= endpos){
		++n;
		lua_pushnumber(L,n);
		lua_pushlstring(L, src+pos, endpos-pos+1);
		lua_settable(L,-3);
	}

	return 1;
}

//创建部分
int luaopen_csplit(lua_State *L)
{
    static const struct luaL_Reg l[] = {
        { "csplit", split },
        { "csplit_to_table", split_to_table },
        { "csplitsql", splitsql },
        { NULL, NULL}
    };
	luaL_newlib(L,l);
	return 1;
}
