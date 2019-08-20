local skynet = require "skynet"
local mysql = require "mysql"
local logger = require "logger"
local futil = require "futil"
require "skynet.manager"

local mysql_service, mysql_dbname = ...

local mysqlconf={}
local mysqlhandle
local sqlStat = {
	total = {
		cnt = 0,
		time = 0.0,
		avg = 0.0,
	},
	sqls = {},
}

local function dbgInfo()
	local function fmtStat(oneStat)
		local s = string.format("{cnt = %d, time = %.3f, avg = %.3f}",
			oneStat.cnt, oneStat.time, oneStat.avg)
		return s
	end
	local statMsg = "notice: time is in seconds\n"
	statMsg = statMsg.."total : "..fmtStat(sqlStat.total).."\n"
	for k, v in pairs(sqlStat.sqls) do
		statMsg = statMsg..k.." : "..fmtStat(v).."\n"
	end
	return statMsg
end

local function dosqlStat(sql, startTime, endTime)
	local costTime = endTime - startTime

	sqlStat.total.cnt = sqlStat.total.cnt + 1
	sqlStat.total.time = sqlStat.total.time + costTime
	sqlStat.total.avg = sqlStat.total.time / sqlStat.total.cnt

	if not sqlStat.sqls[sql] then
		sqlStat.sqls[sql] = {}
		sqlStat.sqls[sql].cnt = 0
		sqlStat.sqls[sql].time = 0.0
		sqlStat.sqls[sql].avg = 0.0
	end

	local theSql = sqlStat.sqls[sql]
	theSql.cnt = theSql.cnt + 1
	theSql.time = theSql.time + costTime
	theSql.avg = theSql.time / theSql.cnt
end

local function readconf()
	assert(mysql_dbname,"mysql_service readconf Error,dbname is NULL")
	mysqlconf.dbname = mysql_dbname
	mysqlconf.host = skynet.getenv(string.format("%s_host",mysql_dbname))
	mysqlconf.port = skynet.getenv(string.format("%s_port",mysql_dbname))
	mysqlconf.user = skynet.getenv(string.format("%s_user",mysql_dbname))
	mysqlconf.pwd  = skynet.getenv(string.format("%s_pwd",mysql_dbname))
end

local function makeConn()
	assert(mysqlconf.dbname,string.format("mysql_service makeConn Error,conf is NULL:%s",mysqlconf.dbname))
	local conf = {
		host = mysqlconf.host,
		port = mysqlconf.port,
		user = mysqlconf.user,
		password = mysqlconf.pwd,
		database = mysqlconf.dbname,
		max_packet_size = 1024*1024
	}

	local conn = mysql.connect(conf)
	if not conn then
		logger.err("mysql_service makeConn fail, database = %s", conf.databas)
	else
		logger.info("mysql_service makeConn success, database = %s" ,conf.database)
	end
	return conn
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

local function mysql_err(res, sql)
    if res.badresult == true then
        logger.err("mysql_service do_sql error, res = %s, sql = [[%s]]", futil.toStr(res), sql)
        return true
    end

    return false
end

local function do_sql(session, address, sql, ...)
	if not mysqlhandle then
		mysqlhandle = makeConn()
		if not mysqlhandle then
			logger.err("mysql_service cannot make conn to database:%s",mysqlconf.dbname)
            logger.err("exec sql fail:%s",sql)
            skynet.ret(skynet.pack(nil))
		end
	end

	local sTime = skynet.time()
    local result = mysqlhandle:query(sql)
    --判断是否执行sql出错
    if mysql_err(result,sql) then
        result = nil
    end
    --session 为0表示不需要回应
    if session ~= 0 then
        skynet.ret(skynet.pack(result))
    end
	dosqlStat(sql, sTime, skynet.time())
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, sql, ...)
		local ok, err = pcall(do_sql, session, address, sql, ...)
		if not ok then
			logger.err("mysql_service err: %s", err)
			if isConnErr(err) then
				logger.err("mysql_service conn err, reconnect, err = %s", err)
				mysqlhandle = makeConn()
			end
			skynet.error("mysql_service query sql error:", session, address, sql) 
		end
	end)

	readconf()

	mysqlhandle = makeConn()

	skynet.info_func(dbgInfo)

	logger.info("mysql_service register:%s",mysql_service)
	skynet.register(mysql_service)
end)
