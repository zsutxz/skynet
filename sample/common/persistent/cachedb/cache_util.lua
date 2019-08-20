local skynet = require "skynet"
local mysql = require "mysql"
local logger = require "logger"
require "skynet.manager"
local cjson = require "cjson"

local mysql_util = require "mysql_util"
local redis_util = require "redis_util"
local cache_conf = require "cache_conf"
local print_t = require "print_t"

local cache_util={}

--[[
	增加一个db连接，需要修改两个配置:
		1. services/persistent/cachedb/cache_conf.lua 
		2. dbcache/*.lua
]]--

function cache_util.init()
	--init mysql dbhandle
	mysql_util.init()

	--init redis dbhandle
	redis_util.init()

	--skynet.uniqueservice("proxyloader")
end

function cache_util.call(dbname, cache_name, args)
	assert(not args or type(args) == "table","query cache err, args must be table")
    args = args or {}
	local dbcache = cache_conf[dbname]
	assert(dbcache,"query db cache conf not exists "..dbname)
	local cacheconf = dbcache[cache_name]
	assert(cacheconf,"query cache conf not exists "..cache_name)

	--print_t(dbcache)
	--print(" /n")
	--print_t(cacheconf)

	--pattern
	local pattern = cacheconf.pattern or "$([%w_]+)"
	local redispt = cacheconf.redispt or " "

	--1.执行 redis call
	if cacheconf.redis then
		local ret = redis_util.query_with_gsub(cacheconf.redis, args, redispt, pattern)

        --超时
        if cacheconf.expire and cacheconf.cachekey then
            local rediskey = string.gsub(cacheconf.cachekey,pattern,args)
            redis_util.querycmd("EXPIRE",rediskey,cacheconf.expire)
        end
		
		skynet.error("cacheconf.args ,redispt:",cacheconf.args,redispt)

        return ret
	end
	
	--2.执行sql，以及缓存
	if cacheconf.sql then
		--缓存定制版本
		if cacheconf.queryrd and cacheconf.cacherd then
			--查询缓存
			local qyresult = redis_util.query_with_gsub(cacheconf.queryrd, args, redispt, pattern)
			if qyresult and (type(qyresult) ~= "table" or #qyresult > 0 ) then
				return qyresult
			end

			--缓存没有，查询mysql
			local sql = args and string.gsub(cacheconf.sql, pattern, args) or cacheconf.sql 
			local sqlcache = mysql_util.query(dbname,cache_name,sql,cacheconf.divide)

			--写入缓存
			if sqlcache ~= nil then
				for _,col in pairs(sqlcache) do
                    local rds = redis_util.query_with_gsub(cacheconf.cacherd, col, redispt, pattern)
					if rds ~= "OK" and rds ~= 1 then
						logger.warn(" 写入缓存 may fail:dbname:%s,cache_name:%s",dbname,cache_name)
					end

					--超时
					if cacheconf.expire and cacheconf.cachekey then
						local rediskey = string.gsub(cacheconf.cachekey,pattern,col)
						redis_util.querycmd("EXPIRE",rediskey,cacheconf.expire)

					end
				end
				--[[
				--expire
				if cacheconf.expire and cacheconf.cachekey then
					local rediskey = string.gsub(cacheconf.cachekey,pattern,args)
					redis_util.query_script("expires",rediskey,cacheconf.expire)
				end
				--]]
			end
			--返回
			return redis_util.query_with_gsub(cacheconf.queryrd, args, redispt, pattern)
		--默认缓存版本
		elseif cacheconf.cachekey then
			--查询缓存
			local rdskey = args and string.gsub(cacheconf.cachekey, pattern, args) or cacheconf
			local rdscache = redis_util.querycmd("GET",rdskey)
			if rdscache then
				--str decode tb
				return cjson.decode(rdscache)
			end

			--缓存没有，查询mysql
			local sql = args and string.gsub(cacheconf.sql, pattern, args) or cacheconf.sql 
			local sqlcache = mysql_util.query(dbname,cache_name,sql,cacheconf.divide)
			--写入缓存
			if sqlcache ~= nil then
				local seriredis = cjson.encode(sqlcache)
				local rds
				if cacheconf.expire then
					--expire redis key
					rds = redis_util.querycmd("SETEX",rdskey,cacheconf.expire,seriredis)
				else
					rds = redis_util.querycmd("SET",rdskey,seriredis)
				end
				if rds ~= "OK" then
					logger.warn("cache_util.call warn, set redis fail,dbname:%s,cache_name:%s",dbname,cache_name)
				end
			end

			return sqlcache
		else
			local sql = args and string.gsub(cacheconf.sql, pattern, args) or cacheconf.sql 
			logger.info("%s,%s,%s",dbname,cache_name,sql)
			local qyresult = mysql_util.query(dbname,cache_name,sql,cacheconf.divide)
			--清理缓存
			if cacheconf.clearrd then
                redis_util.excute_with_gsub(cacheconf.clearrd , args, redispt, pattern)
			end

			return qyresult
		end	--
	end --cacheconf.sql
end

function cache_util.send(dbname, cache_name, args)
	assert(args == nil or type(args) == "table","excute cache err, args must be table")
	local dbcache = cache_conf[dbname]
	assert(dbcache,"query db cache conf not exists "..dbname)
	local cacheconf = dbcache[cache_name]
	assert(cacheconf,"query cache conf not exists "..cache_name)
	--pattern
	local pattern = cacheconf.pattern or "$([%w_]+)"
	local redispt = cacheconf.redispt or " "

	--执行 sql send
	if cacheconf.sql then
		local sql = args and string.gsub(cacheconf.sql, pattern, args) or cacheconf.sql
		mysql_util.excute(dbname,cache_name,sql,cacheconf.divide)
	end

	--执行 redis send
	if cacheconf.clearrd then
		redis_util.excute_with_gsub(cacheconf.clearrd, args, redispt, pattern)
	end

end

return cache_util
