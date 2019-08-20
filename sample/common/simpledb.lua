local skynet = require "skynet"
local redis = require "redis"
local logger = require "logger"
require "skynet.manager"

local redis_host = skynet.getenv "redis_host"
local redis_port = skynet.getenv "redis_port"
local redis_auth = skynet.getenv "redis_auth"

local redisdb
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

local function makeConn()
	local conf = {
		host = redis_host,
		port = redis_port,
		auth = redis_auth,
	}
	local conn = redis.connect(conf)
	if not conn then
		skynet.error(string.format("simpledb makeConn fail, ip = %s, port = %s, auth = %s",
			conf.host, conf.port, conf.auth))
	end
	logger.info("simpledb makeConn success, ip = %s, port = %s, auth = %s",
			conf.host, conf.port, conf.auth)
	
	return conn
end

local function do_cmd(session, address, cmd, ...)
	if not redisdb then
		redisdb = makeConn()
		if not redisdb then
			error("simpledb cannot make conn to redis")
		end
	end

	local f = redisdb[string.lower(cmd)]
	local sTime = skynet.time()

	skynet.ret(skynet.pack(f(redisdb, ...)))
	doCmdStat(cmd, sTime, skynet.time())
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
		local ok, err = pcall(do_cmd, session, address, cmd, ...)
		if not ok then
			logger.err("simpledb err: %s", err)
			if isConnErr(err) then
				logger.err("simpledb conn err, reconnect, err = %s", err)
				redisdb = makeConn()
			end

			local fp = ...
			if type(fp) == "table" then
				skynet.error("simpledb error:", session, address, cmd, table.tostring(fp))
			else
				skynet.error("simpledb error:", session, address, cmd, ...)
			end
			error(err)	-- ensure skynet ret
		end
	end)

	redisdb = makeConn()
	if not redisdb then
		skynet.error("simpledb fail to connect redis")
		error("simpledb fail to connect redis")
		return
	end

	skynet.info_func(dbgInfo)
	skynet.register ".simpledb"
end)
