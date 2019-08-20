local skynet = require "skynet"
local redis = require "redis"
local logger = require "logger"
require "skynet.manager"

local server_id, redis_host, redis_port = ...

if not server_id then
	server_id = ".redis_db"
end

if not redis_host then
	redis_host = skynet.getenv "redis_host"
end

if not redis_port then
	redis_port = skynet.getenv "redis_port"
end

local conf = {
	host = redis_host,
	port = redis_port,
}

local db
local cmdStat = {
	total = {
		cnt = 0,
		time = 0.0,
		avg = 0.0,
	},
	cmds = {},
}

local function fmtStat(oneStat)
	local s = string.format("{cnt = %d, time = %.3f, avg = %.3f}",
		oneStat.cnt, oneStat.time, oneStat.avg)
	return s
end

local function dbgInfo()
	local statMsg = "notice: time is in seconds\n"
	statMsg = statMsg.."total : "..fmtStat(cmdStat.total).."\n"
	for k, v in pairs(cmdStat.cmds) do
		statMsg = statMsg..k.." : "..fmtStat(v).."\n"
	end
	return statMsg
end

local function doCmdStat(cmd, startTime, endTime)
	local costTime = endTime - startTime

	cmdStat.total.cnt = cmdStat.total.cnt + 1
	cmdStat.total.time = cmdStat.total.time + costTime
	cmdStat.total.avg = cmdStat.total.time / cmdStat.total.cnt

	if not cmdStat.cmds[cmd] then
		cmdStat.cmds[cmd] = {}
		cmdStat.cmds[cmd].cnt = 0
		cmdStat.cmds[cmd].time = 0.0
		cmdStat.cmds[cmd].avg = 0.0
	end

	local theCmd = cmdStat.cmds[cmd]
	theCmd.cnt = theCmd.cnt + 1
	theCmd.time = theCmd.time + costTime
	theCmd.avg = theCmd.time / theCmd.cnt
end

local function isConnErr(errmsg)
	if not errmsg then
		return false
	end
	if type(errmsg) == 'string' and string.find(errmsg, "Connect to") then
		return true
	end
	return false
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        cmd = string.lower(cmd)
        local f = db[cmd]
        if not f then
            logger.err("redis_db err!!!!!!!error:Unknown command %s", tostring(cmd))
            skynet.ret(skynet.pack(nil))
        end

        local sTime = skynet.time()
        local ok,res = pcall(f, db, ...)
        if not ok then
            local tb = table.pack(...)
            local s1 = table.concat(tb)
            logger.err("redis_db err, redis query fail,err:%s, cmd:%s %s",res, cmd, s1)
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
        else
            if session ~= 0 then
                skynet.ret(skynet.pack(res))
            end
        end
        doCmdStat(cmd, sTime, skynet.time())
    end)

	skynet.error("redis_db server: ",server_id,conf.host, conf.port)
	db = redis.connect(conf)

	skynet.info_func(dbgInfo)

	skynet.register(server_id)
end)
