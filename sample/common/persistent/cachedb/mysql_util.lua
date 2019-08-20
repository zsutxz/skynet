local skynet = require "skynet"
local mysql = require "mysql"
local logger = require "logger"
require "skynet.manager"
local futil = require "futil"
local libsql_split = require "libsql_split"
require "string_util"

local mysql_util={}

--[[
	mysql_dbservice
	{
		"dbname1" : 
		{
			"wkIndex"  : 0		--下一次投递的服务index
			"nWorker"  : 2		--总worker数量
			"wkService"   :		--services名字数组
			{
				1 : service1
				2 : service2
			}
		}
		"dbname2" : 
		{
			"wkIndex"  : 0		--下一次投递的服务index
			"nWorker"  : 1		--总worker数量
			"wkService"   : 
			{
				1 : service3
			}
		}
	}
]]--

local mysql_dbservice = {}

local function readConf()
	local mysql_dbname = string.csplit_to_table(skynet.getenv("mysqldb"),";")

	--each dbname 下的每个service启动
	for k,dbname in pairs(mysql_dbname) do
		--service list
		mysql_dbservice[dbname] = {}
		mysql_dbservice[dbname].wkIndex = 0
		local envstr = skynet.getenv(string.format("%s_svr",dbname))
		mysql_dbservice[dbname].wkService = string.csplit_to_table(envstr,";")
	end
end

function mysql_util.init()
	--each dbname 下的每个service启动
	for dbname,tbWorker in pairs(mysql_dbservice) do
		--init service
		local lwkService = tbWorker.wkService
		for k,svrname in pairs(lwkService) do
			skynet.newservice("mysql_service",svrname,dbname)
            skynet.call(svrname,"lua", "set names utf8mb4;")
		end
	end

end

function mysql_util.query(dbname,cachename,sql,divide)
    divide = divide or false

	--dbname 取出对应的服务 table
	local mysql_dbservice_dbsvr = mysql_dbservice[dbname]
	--print("mysql_dbservice_dbsvr：",mysql_dbservice_dbsvr)

	if not mysql_dbservice_dbsvr then
		logger.err("mysql_util query error,database services no exists:%s",dbname)
        return nil
	end

	--当前应该投递的index
	local wkIndex = mysql_dbservice_dbsvr.wkIndex + 1
	mysql_dbservice_dbsvr.wkIndex = wkIndex%(#mysql_dbservice_dbsvr.wkService)

	--print("wkIndex：",mysql_dbservice_dbsvr.wkIndex)

	local wkService=mysql_dbservice_dbsvr.wkService
	if not wkService[wkIndex] then
		logger.err("mysql_util query error,worker services not exists:%s",dbname)
        return nil
	end

    -- --divide sql，分表table的sql处理
    -- if divide then
    --    local ok,out_put = libsql_split.sql_csplit(dbname,sql) 
    --    if ok == 0 then
    --        sql = out_put
    --    else
    --        --报错
    --        logger.err("mysql_util query error: %s.%s ,sql_csplit fail: %s",dbname,cachename,out_put)
    --        return nil
    --    end
    -- end

	return skynet.call(wkService[wkIndex],"lua",sql)
end

function mysql_util.excute(dbname,cachename,sql,divide)
    divide = divide or false
	--dbname 取出对应的服务 table
	local mysql_dbservice_dbsvr = mysql_dbservice[dbname]
	
	if not mysql_dbservice_dbsvr then
		logger.err("mysql_util excute error,database no exists: %s",dbname)
        return nil
	end

	--当前应该投递的index
	local wkIndex = mysql_dbservice_dbsvr.wkIndex + 1
	mysql_dbservice_dbsvr.wkIndex = wkIndex%(#mysql_dbservice_dbsvr.wkService)

	local wkService=mysql_dbservice_dbsvr.wkService
	if not wkService[wkIndex] then
		logger.err("mysql_util excute error,worker services not exists: %s",dbname)
        return nil
	end

    --divide sql，分表table的sql处理
    if divide then
        local ok,out_put = libsql_split.sql_csplit(dbname,sql) 
        if ok == 0 then
            sql = out_put
        else
            --报错
            logger.err("mysql_util excute error: %s.%s,sql_csplit fail: %s",dbname,cachename,out_put)
            return nil
        end
    end
    skynet.send(wkService[wkIndex],"lua",sql)
end

readConf()
return mysql_util
