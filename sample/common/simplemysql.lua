local skynet = require "skynet"
local redis = require "redis"
local logger = require "logger"
require "skynet.manager"
local mysql = require "mysql"

local mysqlconf = {}
local mysqlhandle = {}

local function string_split(splitstr,splitchar)
	local split_table = {}
	while(true) do
		local pos = string.find(splitstr,splitchar)
		if (not pos) then
			split_table[#split_table+1]=splitstr
			break;
		end
		split_table[#split_table+1]=string.sub(splitstr,0,pos-1)
		splitstr=string.sub(splitstr,pos+1,#splitstr)
	end
	return split_table
end

local function readconf()
	local mysqldb = skynet.getenv "mysqldb"
	local result = string_split(mysqldb,";")
	for k,v in pairs(result) do
		if v then
			mysqlconf[v] = {}
			mysqlconf[v].name = v
			mysqlconf[v].host = skynet.getenv(string.format("%s_host",v))
			mysqlconf[v].port = skynet.getenv(string.format("%s_port",v))
			mysqlconf[v].user = skynet.getenv(string.format("%s_user",v))
			mysqlconf[v].pwd  = skynet.getenv(string.format("%s_pwd",v))
		end
	end
end

local function makeConn(dbname)
	assert(mysqlconf[dbname],"makeConn Error,conf is NULL")
	local conf = {
		host = mysqlconf[dbname].host,
		port = mysqlconf[dbname].port,
		user = mysqlconf[dbname].user,
		password = mysqlconf[dbname].pwd,
		database = mysqlconf[dbname].name,
		max_packet_size = 1024*1024
	}
	local conn = mysql.connect(conf)
	if not conn then
		skynet.error(string.format("simplemysql makeConn fail, ip = %s, port = %s, user = %s, password = %s ,database = %s" ,
			conf.host, conf.port, conf.user, conf.password, conf.database))
	end
	logger.info(string.format("simplemysql makeConn success, ip = %s, port = %s, user = %s, password = %s ,database = %s" ,
		conf.host, conf.port, conf.user, conf.password, conf.database))
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

local function do_sql(session, address, dbname, sql, ...)
	if not mysqlhandle[dbname] then
		if not mysqlconf[dbname] then 
			skynet.error(string.format("database conf not exists:%s",dbname))
			error(string.format("database conf not exists:%s",dbname))
		else
			mysqlhandle[dbname] = makeConn(dbname)
			if not mysqlhandle[dbname] then
				skynet.error(string.format("simplemysql cannot make conn to database:%s",dbname))
			end
		end
	end

	skynet.ret(skynet.pack(mysqlhandle[dbname]:query(sql)))
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, dbname, sql, ...)
		local ok, err = pcall(do_sql, session, address, dbname, sql, ...)
		if not ok then
			logger.err("simplemysql err: %s", err)
			if isConnErr(err) then
				logger.err("simplemysql conn err, reconnect, err = %s", err)
				mysqlhandle[dbname] = makeConn(dbname)
			end

			skynet.error("simplemysql query sql error:", session, address, dbname, sql) 
		end
	end)

	readconf()
	for dbname,conf in pairs(mysqlconf) do
		mysqlhandle[dbname] = makeConn(dbname)
		if not mysqlhandle[dbname] then
			skynet.error(string.format("simplemysql fail to connect database:%s",dbname))
			error(string.format("simplemysql fail to connect database:%s",dbname))
			return
		end
	end
	skynet.register(".simplemysql")
	
end)
