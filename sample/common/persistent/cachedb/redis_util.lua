local skynet = require "skynet"
local redis = require "redis"
local logger = require "logger"
require "string_util"
require "skynet.manager"
local script_conf = require "script_conf"

local redis_util = {}
local redis_svr = skynet.getenv "redis_svr"

--redis script 
local script_rsa = {}

local function load_script()
	for key,script in pairs(script_conf) do
		script_rsa[key] = skynet.call(redis_svr,"lua","script","load",script) 
		if script_rsa[key] == nil then
			logger.warn("load redis script fail,key:"..key)
		end
	end
end

function redis_util.init()
	--init service
	--assert(redis_svr,"redis_util.init err,svr name is nil")
	skynet.newservice("redis_db",redis_svr)
	load_script()
end

function redis_util.query_with_gsub(redisstr, args, redispt, pattern)
    pattern = pattern or "$([%w_]+)"
	redispt = redispt or " "
    local redis_cmd = string.csplit_to_table(redisstr, redispt)
    for _id,_rd in pairs(redis_cmd) do
        redis_cmd[_id] = string.gsub(_rd, pattern, args)
    end
	return skynet.call(redis_svr, "lua", table.unpack(redis_cmd))
end

function redis_util.querycmd(...)
	return skynet.call(redis_svr, "lua", ...)
end

function redis_util.excute_with_gsub(redisstr, args, redispt, pattern)
    pattern = pattern or "$([%w_]+)"
	redispt = redispt or " "
    local redis_cmd = string.csplit_to_table(redisstr, redispt)
    for _id,_rd in pairs(redis_cmd) do
        redis_cmd[_id] = string.gsub(_rd, pattern, args)
    end
	skynet.send(redis_svr, "lua", table.unpack(redis_cmd))
end

--script
function redis_util.query_script(script,...)
	local scriptRsa = script_rsa[script]
	assert(scriptRsa,"query_script fail,script rsa is nil:"..script)
	skynet.call(redis_svr,"lua","EVALSHA",scriptRsa,1,...)
end

function redis_util.excute_script(script,...)
	local scriptRsa = script_rsa[script]
	assert(scriptRsa,"query_script fail,script rsa is nil:"..script)
	skynet.send(redis_svr,"lua","EVALSHA",scriptRsa,1,...)
end

return redis_util
