local skynet = require "skynet"
local redis = require "redis"
local crypt = require "crypt"
local futil = require "futil"
local logger = require "logger"
local keygen = require "redis_key_gen"
local json = require "json"
local sqlutil = require "sqlutil"
local query_sharedata = require "query_sharedata"
local skynet_util = require "skynet_util"
local util_redis_script = require "util_redis_script"
local profile = require "profile"
local cmdstat = require "cmdstat"
local conf_util = require "conf_util"
local mongo = require "mongo"
local mongo_coll_gen = require "mongo_coll_gen"
local mysql = require "mysql_timeout"

--local mysql_mydataworker = require "mysql_mydataworker"
require "skynet.manager"
require "tostring"
require "functions"

local _conf = {
	redis_host_single = skynet.getenv "redis_host_single",
	redis_port_single = skynet.getenv "redis_port_single",
	redis_auth_single = skynet.getenv "redis_auth_single",
	rank_redis_host1 = skynet.getenv "rank_redis_host1",
	rank_redis_port1 = skynet.getenv "rank_redis_port1",
	rank_redis_auth1 = skynet.getenv "rank_redis_auth1",
	rank_redis_host2 = skynet.getenv "rank_redis_host2",
	rank_redis_port2 = skynet.getenv "rank_redis_port2",
	rank_redis_auth2 = skynet.getenv "rank_redis_auth2",
	rank_redis_host3 = skynet.getenv "rank_redis_host3",
	rank_redis_port3 = skynet.getenv "rank_redis_port3",
	rank_redis_auth3 = skynet.getenv "rank_redis_auth3",

	mongo_host = skynet.getenv "mongo_host",
	mongo_port = skynet.getenv "mongo_port",
	mongo_dbname = skynet.getenv "mongo_dbname",
	mongo_user = skynet.getenv "mongo_user",
	mongo_pwd = skynet.getenv "mongo_pwd",

	mysql_host = skynet.getenv "mysql_host",
	mysql_port = skynet.getenv "mysql_port",
	mysql_user = skynet.getenv "mysql_user",
	mysql_pwd  = skynet.getenv "mysql_pwd",
	db_game = skynet.getenv "db_game",

}

local _self = {
	workernum = tonumber(...),	
	serviceName = nil,
}

local gamedb
local const
local globalconf
local mongoc
local mongo_fish3d
local redisdb_single --单实例redis，单独用于处理需要eval、evalsha（注意：rankredis本来就是单实例redis，可以执行这两个命令）
local rank_redisdb_arr = {} --有些服务器如果没配置rank_redis_host，会为nil
local command = {}
local cmdStat = cmdstat.new()
local rankdb = {
	test_rank_redisdb = nil,
}

--[[
mongo使用原则：
× 必须使用safe_开头的函数进行insert、update、delete操作
]]

--[[
note: 分多个rank_redis的目的是为以后扩容留下余地，一开始单个物理机开三个redis实例，等以后容量上去之后，可以直接把实例迁到别的物理机完成扩容
排行榜所在的rank_redis分配:
rank_redis_host1: 
rank_redis_host2: 
rank_redis_host3: 
]]

--[[
数据存储原则：
* mongo里面单个document的大小不能超过16MB
* 新增一个collection要在mongo_coll.lua里面写出来
* user_basic的每个字段要在const的定义出来
]]

local function testCanExecutesql()
	if _self.workernum ~= 0 then
		logger.info("workernum is not 0")
		return 0
	end
	local runenv = skynet.getenv "runenv"
	if runenv ~= "dev" then
		logger.info("runenv is not dev")
		return 0
	end
	logger.info("testCanExecutesql ok")
	return 1
end


function _self.executeSql(sql, db, ingored_errno)
	assert(sql and db)
	local dbres = db:query(sql)
	local ok = sqlutil.checkMySqlErr(dbres, sql, ingored_errno)
	if not ok then
		error('sql error')
	end
	return dbres
end

function _self.mysql_updateOrinsert(tbname, key_value_tb, wheres_tb)
	local keys = {}
	local values = {}
	local updates = {}

	if wheres_tb==nil then
		wheres_tb = {}
	end
	for k, v in pairs(wheres_tb) do
		table.insert(keys, k)
		table.insert(values, sqlutil.quote_if_string(v))
	end

	for k, v in pairs(key_value_tb) do
		table.insert(keys, k)
		table.insert(values, sqlutil.quote_if_string(v))
		table.insert(updates, string.format("%s=values(%s)", k, k))
	end

	local keys_str = table.concat(keys, ",")
	local values_str = table.concat(values, ",")
	local updates_str = table.concat(updates, ",")

	local sql = string.format("insert into %s(%s) values(%s) on duplicate key update %s", 
		tbname, keys_str, values_str, updates_str)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_insert(tbname, key_value_tb)
	local keys = {}
	local values = {}

	for k, v in pairs(key_value_tb) do
		table.insert(keys, k)
		table.insert(values, sqlutil.quote_if_string(v))
	end

	local keys_str = table.concat(keys, ",")
	local values_str = table.concat(values, ",")

	local sql = string.format("insert into %s(%s) values(%s)", 
		tbname, keys_str, values_str)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_update(tbname, sets_tb, wheres_tb)
	local sets = {}
	local wheres = {}

	for k, v in pairs(sets_tb) do
		table.insert(sets, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end
	for k, v in pairs(wheres_tb) do
		table.insert(wheres, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end
	
	local sets_str = table.concat(sets, ",")
	local wheres_str = table.concat(wheres, " and ")

	local sql = string.format("update %s set %s where %s",  tbname, sets_str, wheres_str)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_delete(tbname, key_value_tb, wheres_tb)
	local conds = {}
	for k, v in pairs(key_value_tb) do
		table.insert(conds, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end
	if wheres_tb==nil then
		wheres_tb ={}
	end
	for k, v in pairs(wheres_tb) do
		table.insert(conds, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end
	local conds_str = table.concat(conds, " and ")
	local sql = string.format("delete from %s where %s", tbname, conds_str)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_select_star(tbname, wheres_tb, other_arg)
	local conds = {}
	if other_arg==nil then
		other_arg=""
	end
	for k, v in pairs(wheres_tb) do
		table.insert(conds, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end

	local conds_str = table.concat(conds, " and ")
	local sql = string.format("select * from %s where %s %s", tbname, conds_str, other_arg)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_select_star_byor(tbname, wheres_or_tb, other_arg)
	local conds = {}
	if other_arg==nil then
		other_arg=""
	end
	for k, v in pairs(wheres_or_tb) do
		table.insert(conds, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end

	local conds_str = table.concat(conds, " or ")
	local sql = string.format("select * from %s where %s %s", tbname, conds_str, other_arg)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_select_all(tbname)
	local sql = string.format("select * from %s", tbname)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function _self.mysql_select_columns(tbname, columns, wheres_tb, other_arg)
	local conds = {}
	if other_arg==nil then
		other_arg=""
	end
	for k, v in pairs(wheres_tb) do
		table.insert(conds, string.format("%s=%s", k, sqlutil.quote_if_string(v)))
	end

	local columns_str = table.concat(columns, ",")
	local conds_str = table.concat(conds, " and ")
	local sql = string.format("select %s from %s where %s %s", columns_str, tbname, conds_str, other_arg)
	local dbres = _self.executeSql(sql, gamedb)
	return dbres
end

function command.test()
	if testCanExecutesql() == 0 then
		return
	end
	--add test code below

	--local dbres = _self.executeSql("select * from test", gamedb)
	local temp_sql = string.format("insert into test(id, name) values(%d, '%s')", 5,  os.time())
	--local temp_sql = string.format("delete from  test   where id=4")
	--local temp_sql = "select * from test"
	local dbres = _self.executeSql(temp_sql, gamedb)
	logger.info("dbres = %s", futil.tostr(dbres))
end


local function get_redis_expire_time()
	return globalconf.redis_expire_time or const.redis.default_ex
end

local function errorArg(funcName, ...)
	local s
	for i = 1, select('#', ...) do
		local v = select(i, ...)
		if s then
			s = string.format("%s, %s", s, futil.toStr(v))
		else
			s = futil.toStr(v)
		end
	end
	error(string.format("%s, invalid arg, args = %s", funcName, s))
end

function _self.autoPrintStat()
	while true do
		local interval = conf_util.get_cmdstat_service_output_interval()
		local T = interval*100
		skynet.sleep(T)
		if globalconf.cmdstat_service_output_enable == 1 then
			logger.info("DATAWORKER STAT %s : \n%s", _self.workernum, cmdStat:str())
		end
	end
end

function _self.make_mysql_conn(host, port, database, user, password, max_packet_size)
    local mysqldb = mysql.connect({host = host, port = port, database = database,
        user = user, password = password, max_packet_size = max_packet_size,
        queue = function () return globalconf.mysql_queue_enable == 1 end})
    if not mysqldb then
    	error(string.format("%s fail to connect to mysql, %s:%s:%s, %s/%s", 
    		_self.serviceName, host, port, database, user, password))
    end
    logger.info("%s make_mysql_conn, %s:%s:%s, %s/%s", _self.serviceName, 
    	host, port, database, user, password)
    return mysqldb
end

--创建redis连接，如果要创建的连接已经在已连接数组，则直接返回，否则创建新连接，并加入已连接数组
--return redisdb
function _self.make_redis_conn(host, port, auth, connected_redis)
	if not (host and port) then
		return nil
	end
	for _, v in pairs(connected_redis) do
		if v.host == host and v.port == port then
			return v.db
		end
	end
	local redis_db = redis.connect({host = host, port = port, auth = auth,})
	if not redis_db then
		error(string.format("%s fail to connect to redis, %s:%s, %s", 
			_self.serviceName, host, port, auth))
	end
	logger.info("%s make_redis_conn, %s:%s, %s", _self.serviceName, host, port, auth)
	table.insert(connected_redis, {db = redis_db, host = host, port = port})
	return redis_db
end

function _self.get_mongo_coll(coll_name)
	assert(coll_name)
	if not _self.mongo_coll then
		_self.mongo_coll = {}
	end
	local coll = _self.mongo_coll[coll_name] 
	if not coll then
		coll = mongo_fish3d:getCollection(coll_name)
		assert(coll)
		_self.mongo_coll[coll_name]  = coll
	end
	return coll
end

function _self.get_mongodb()
	return mongo_fish3d
end

function _self.get_sql_gamedb()
	return gamedb
end

function _self.get_const()
	return const
end

function _self.ensure_index(collname, keyname)
	assert(collname and keyname)
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:createIndex({keyname})
	logger.info("ensure_index: %s, %s, dbres = %s", collname, keyname, futil.tostr(dbres))
	return dbres
end

function _self.make_sure_mongo_index()
	if _self.workernum ~= 0 then return end
	logger.info("make_sure_mongo_index begin")
	xpcall(_self.ensure_index, skynet_util.handle_err, mongo_coll_gen.userbind(), "uid_0")
	xpcall(_self.ensure_index, skynet_util.handle_err, mongo_coll_gen.userbind(), "uid_1")
	xpcall(_self.ensure_index, skynet_util.handle_err, mongo_coll_gen.open_info(), "memberid")
	xpcall(_self.ensure_index, skynet_util.handle_err, mongo_coll_gen.pay_order(), "order_id")
	xpcall(_self.ensure_index, skynet_util.handle_err, mongo_coll_gen.pay_order(), "uid")	
	logger.info("make_sure_mongo_index finish")
end

function command.redis_time(key)
	local r = redisdb_single:eval(util_redis_script.time, 1, key or 1)
	return tonumber(r[1]), tonumber(r[2])
end

function command.redis_eval_try_sha(_db, script, script_sha, num_key, ...)
	local ok, r = pcall(_db.evalsha, _db, script_sha, num_key, ...)
	if ok then return r end
	logger.err("redis_eval_try_sha r = %s", r)
	if type(r) == "string" and r:find("NOSCRIPT") then
		return _db:eval(script, num_key, ...)
	end
	skynet.error("dataworker redis_eval_try_sha fail, script=", script)
	error(r)
end

function command.refresh_redis_lock(lock_key, val, expire_time)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.refresh_lock, util_redis_script.refresh_lock_sha, 1,
		lock_key, val, expire_time or const.master_lock.lock_default_ex)
	if r == "OK" then
		return true
	end
	return false, r[1], r[2]
end

function command.get_redis_lock(lock_key, val, expire_time)
	expire_time = expire_time or const.master_lock.lock_default_ex
	local r = redisdb_single:set(lock_key, val, "nx", "ex", expire_time)
	if r == "OK" then
		return true
	end
	return command.refresh_redis_lock(lock_key, val, expire_time)
end

function command.free_redis_lock(lock_key, val)
	return command.redis_eval_try_sha(redisdb_single, util_redis_script.free_lock, util_redis_script.free_lock_sha, 1,
		lock_key, val)
end

function command.get_pos_by_openid(openid)
	local rkey = keygen.user_pos(openid)
	local res = redisdb_single:get(rkey)
	return res
end

function command.delete_pos_by_openid(openid, pos)
	local rkey = keygen.user_pos(openid)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.delete_pos_by_openid, util_redis_script.delete_pos_by_openid_sha, 1,
		rkey, pos)
	return true
end

function command.update_pos_by_openid(openid, pos)
	local rkey = keygen.user_pos(openid)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.update_pos_by_openid, util_redis_script.update_pos_by_openid_sha, 1, 
		rkey, const.user_pos.expire, pos)
	if r == "OK" then
		return true
	end
	return false, r[2]
end

function command.register_pos_by_openid(openid, pos)
	local rkey = keygen.user_pos(openid)
	local res = redisdb_single:set(rkey, pos, "nx", "ex", const.user_pos.expire)
	if res ~= "OK" then
		logger.warn("register_pos_by_openid fail, res = %s, openid = %s, pos = %s", 
			res, openid, pos)
		return false
	end	
	return true
end


-- TODO: implementation
function command.get_resp_cache(uid)
	logger.warn("dataworker get_resp_cache no implementation")
	return ""
end

-- TODO: implementation
function command.save_resp_cache()
	logger.warn("dataworker save_resp_cache no implementation")
	return true
end

-- TODO: implementation
function command.query_total_user_cnt()
	return 1
end

--创建open_info，如果存在，则会失败
function command.create_open_info(openid, kv)
	assert(openid and kv and next(kv))
	local coll = _self.get_mongo_coll(mongo_coll_gen.open_info())
	kv._id = openid
	local dbres = coll:safe_insert(kv)
	logger.info("create_open_info, dbres = %s", futil.tostr(dbres))
	return true
end

--更新open_info，只更新已经存在的，如果不存在，不会创建文档
function command.update_open_info(openid, kv)
	assert(openid and kv and next(kv))
	local coll = _self.get_mongo_coll(mongo_coll_gen.open_info())
	local dbres = coll:safe_update({_id = openid}, {["$set"] = kv})
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.info("update_open_info fail, dbres = %s", futil.tostr(dbres))
		return false
	end
	return true
end

function command.get_open_info(openid)
	assert(openid)
	local coll = _self.get_mongo_coll(mongo_coll_gen.open_info())
	local dbres = coll:findOne({_id = openid})
	return dbres
end

function command.delete_open_info(openid)
	assert(openid)
	local coll = _self.get_mongo_coll(mongo_coll_gen.open_info())
	coll:delete({_id = openid})
end

--return {[0] = xxx, [1] = xxx} 0 for ios, 1 for android
function command.get_alluid_by_openid(openid)
	assert(openid)
	return command.load_user_bind(openid) or {}
end

function command.get_openid_by_uid(uid)
	assert(uid)
	local collname = mongo_coll_gen.userbind()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne({ ["$or"] = { {uid_0 = uid}, {uid_1 = uid} } })
	local openid = dbres and dbres._id
	return openid
end

function command.get_openid_by_memberid(memberid)
	assert(memberid)
	local collname = mongo_coll_gen.open_info()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne({ memberid =  memberid})
	local openid = dbres and dbres._id
	return openid
end

--用户的基础信息
--除了邮箱、背包、好友之外的数据, 不是特别大的，都放这里
function command.load_user_basic(uid)
	assert(uid)
	local coll = _self.get_mongo_coll(mongo_coll_gen.user_basic())
	local dbres = coll:findOne({_id = uid})
	return dbres
end

--更新user_basic字段，如果不存在，会创建文档
--只支持一层内嵌文档，内嵌文档update的时候，要转换key为文档名.字段名
function command.update_user_basic(uid, kv)
	assert(uid and kv and next(kv))
	local newdata = {}
	for k, v in pairs(kv) do
		if type(v) == "table" then
			for k1, v1 in pairs(v) do
				assert(type(v1) ~= "table")
				local newkey = string.format("%s.%s", k, k1)
				newdata[newkey] = v1
			end
		else
			newdata[k] = v
		end
	end
	local coll = _self.get_mongo_coll(mongo_coll_gen.user_basic())
	local dbres = coll:safe_update( {_id = uid}, {["$set"] = newdata}, {upsert = true} )
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("update_user_basic fail, dbres = %s, uid = %s, kv = %s", futil.tostr(dbres), uid, futil.tostr(kv))
		return false
	end
	return true
end

--通用的生成自增id
function command.gen_inc_id(idtype)
	assert(idtype)
	local coll = _self.get_mongo_coll(mongo_coll_gen.common_inc_id())
	local dbres = coll:findAndModify({
		query = { _id = idtype }, 
		update = { ["$inc"] = { nextid=1 } },
		upsert = true,
		new = true
	})
	if not(dbres and dbres.ok == 1 and dbres.value and dbres.value.nextid) then
		logger.err("gen_inc_id fail, args = %s, dbres = %s", idtype, futil.tostr(dbres))
		return nil
	end
	assert(type(dbres.value.nextid) == "number")
	return dbres.value.nextid
end

--return {openid = xx}
function command.load_outer_bind(account_plat, outerid)
	assert(account_plat and outerid)
	if not  const.account_plat[account_plat] then
		error(string.format("not support account_plat: %s", account_plat))
	end
	local collname = mongo_coll_gen.outerbind(account_plat)
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne({_id = outerid})
	if not dbres then
		return nil
	end
	return {openid = dbres.openid, token = dbres.token}
end

--be careful, call only when absolutely need
function command.delete_outer_bind(account_plat, outerid)
	assert(account_plat and outerid)
	if not  const.account_plat[account_plat] then
		error(string.format("not support account_plat: %s", account_plat))
	end
	local collname = mongo_coll_gen.outerbind(account_plat)
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:delete({_id = outerid})
	logger.info("delete_outer_bind, dbres = %s", futil.tostr(dbres))
	if not dbres then
		return false
	end
	return dbres
end

--args:  kvs = {openid = xx, [token] = xx}
--return true/false
function command.write_outer_bind(account_plat, outerid, kvs)
	assert(account_plat and outerid and kvs and kvs.openid)
	if not  const.account_plat[account_plat] then
		error(string.format("not support account_plat: %s", account_plat))
	end
	local collname = mongo_coll_gen.outerbind(account_plat)
	local coll = _self.get_mongo_coll(collname)
	kvs["_id"] = outerid
	local dbres = coll:safe_insert(kvs)
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("write_outer_bind fail, args = %s, %s, %s, errmsg = %s", 
			account_plat, outerid, futil.tostr(kvs), futil.tostr(dbres.writeErrors))
		return false
	end
	return true
end

--0 for ios, 1 for android
--请不要改变以下的return行为，有些逻辑需要判空处理
--if no document:  return nil 
--else :                    return {[0] = uid, [1] = uid}
function command.load_user_bind(openid)
	assert(openid)
	local collname = mongo_coll_gen.userbind()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne( { _id = openid } )
	if not dbres then
		return nil
	end
	return {[0] = dbres.uid_0, [1] = dbres.uid_1}
end

--[[
创建openid到uid的绑定
修改此函数需要谨慎，此函数必须保证并发的情况下: 
   1) 仅有一个能写入成功，而不是两个都成功，后一个覆盖了前一个的
   2) 宁愿写入失败，也不能出现后一个覆盖前一个的情况

return true/false
]]
function command.write_user_bind(phone_plat, openid, uid)
	assert(phone_plat and openid and uid)
	if not const.support_phone_plat[phone_plat] then
		error(string.format("not support phone_plat: %s", phone_plat))
	end
	local now_bind = command.load_user_bind(openid)
	local collname = mongo_coll_gen.userbind()
	local coll = _self.get_mongo_coll(collname)
	local fname = string.format("uid_%s", phone_plat)

	if not now_bind then
		--do insert
		logger.info("write_user_bind, do insert, %s, %s, %s", phone_plat, openid, uid)
		local dbres = coll:safe_insert({_id = openid, [fname] = uid})
		if not (dbres and dbres.ok == 1 and dbres.n == 1) then
			logger.err("write_user_bind fail, doinsert, args = %s, %s, %s, errmsg = %s", 
				phone_plat, openid, uid, futil.tostr(dbres.writeErrors))
			return false
		end
		return true
	else
		--do update
		logger.info("write_user_bind, do update, %s, %s, %s", phone_plat, openid, uid)
		local dbres = coll:findAndModify({
			query = { _id = openid, [fname] = mongo.null}, 
			update = { ["$set"] = { [fname]=uid } },
			new = true
		})
		if not (dbres and dbres.value and dbres.value[fname] == uid) then
			logger.err("write_user_bind fail, doupdate, args = %s, %s, %s, errmsg = %s", 
				phone_plat, openid, uid, futil.tostr(dbres))
			return false
		end
		return true
	end
end

function command.delete_user_all_data(openid, phone_plat, uid, ap, outerid)
	local collname = mongo_coll_gen.userbind()
	command.delete_outer_bind(ap, outerid)
	local coll = _self.get_mongo_coll(mongo_coll_gen.user_basic())
	coll:delete({_id = uid})
	
	return true
end

function command.set_room_pos(room_id, slave_svr_name)
	assert(room_id and slave_svr_name)
	local rkey = keygen.room_server()
	return redisdb_single:hset(rkey, room_id, slave_svr_name)
end

function command.get_room_pos(room_id)
	assert(room_id)
	local rkey = keygen.room_server()
	return redisdb_single:hget(rkey, room_id)
end

function command.delete_room_pos(room_id)
	assert(room_id)
	local rkey = keygen.room_server()
	return redisdb_single:hdel(rkey, room_id)
end

function command.get_all_room_pos()
	local rkey = keygen.room_server()
	local dbres = redisdb_single:hgetall(rkey)
	local ret = {}
	for i = 1, #dbres, 2 do
		local room_id = math.tointeger(dbres[i])
		if room_id then ret[room_id] = dbres[i+1] end
	end
	return ret
end

--return {room_id, ...}
function command.get_room_id_list()
	local ret = {}
	local coll = _self.get_mongo_coll(mongo_coll_gen.room_list())
	local dbres = coll:find()
	while dbres and dbres:hasNext() do
		local tmp = dbres:next()
		local room_id = math.tointeger(tmp._id)
		if room_id then
			table.insert(ret, room_id)
		else
			logger.err("get_room_id_list invalid data: %s", futil.tostr(tmp))
		end
	end
	logger.info("get_room_id_list ret: %s", futil.tostr(ret))
	return ret
end

--return {room_id, doll_id, room_type, play_cost, mgr_status}
function command.get_room_info(room_id)
	assert(room_id)
	local coll = _self.get_mongo_coll(mongo_coll_gen.room_list())
	local dbres = coll:findOne({_id = room_id})
	if dbres then
		local ret = {
			room_id = math.tointeger(dbres._id),
			doll_id = math.tointeger(dbres.doll_id),
			room_type = math.tointeger(dbres.room_type),
			play_cost = math.tointeger(dbres.play_cost),
			mgr_status = math.tointeger(dbres.mgr_status),
			round_time = math.tointeger(dbres.round_time),
		}
		return ret
	end
	return nil
end



function command.delete_pos_by_machine_id(game_id, machine_id, pos)
	local rkey = keygen.game_machine_pos(game_id, machine_id)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.delete_pos_by_machine_id, util_redis_script.delete_pos_by_machine_id_sha, 1,
		rkey, pos)
	return true
end

function command.update_pos_by_machine_id(game_id, machine_id, pos)
	local rkey = keygen.game_machine_pos(game_id, machine_id)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.update_pos_by_machine_id, util_redis_script.update_pos_by_machine_id_sha, 1, 
		rkey, const.wawaji_pos.expire, pos)
	if r == "OK" then
		return true
	end
	return false, r[2]
end

function command.get_pos_by_machine_id(game_id,machine_id)
	local rkey = keygen.game_machine_pos(game_id, machine_id)
	local res = redisdb_single:get(rkey)
	return res
end

function command.register_pos_by_machine_id(game_id, machine_id, pos)
	logger.info("before keygen.machine_pos")
	local rkey = keygen.game_machine_pos(game_id, machine_id)
	logger.info("before redisdb_single:set")
	local res = redisdb_single:set(rkey, pos, "nx", "ex", const.machine_pos.expire)
	logger.info("after redisdb_single:set")
	if res ~= "OK" then
		logger.warn("register_pos_by_machine_id fail, res = %s, machine_id = %s, pos = %s", 
			res, machine_id, pos)
		return false
	end	
	logger.info("register_pos_by_machine_id ok, rkey = %s", rkey)
	return true
end

function command.update_room_info(room_id, change_fields)
 	assert(room_id and change_fields and next(change_fields))
 	local coll = _self.get_mongo_coll(mongo_coll_gen.room_list())
 	local dbres = coll:safe_update({_id = room_id}, {["$set"] = change_fields})
 	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
 		logger.err("update_room_info fail, dbres = %s, args = %s, %s",
 			futil.tostr(dbres), room_id, futil.tostr(change_fields))
 		return false
 	end
 	return true
 end 

--支持eval、evalsha, ...
function command.redisdb_single(cmd, ...)
	return redisdb_single[cmd](redisdb_single, ...)
end

function command.create_pay_order(uid, order_id, plat_id, product_id, product, diamond, openid, cash)
	assert(uid and order_id and plat_id and product_id and product and diamond and openid and cash)
	local collname = mongo_coll_gen.pay_order()
	local coll = _self.get_mongo_coll(collname)
	local args = {
		uid = uid,
		order_id = order_id,
		plat_id = plat_id,
		product_id = product_id,
		product = product,
		diamond = diamond,
		openid = openid,
		order_time = os.time(),
		result = const.excharge_result.create,
		status = const.excharge_status.default,
		cash = cash,
	}
	local dbres = coll:safe_insert(args)
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("create_pay_order fail, args = %s, errmsg = %s", 
			futil.toStr(args), futil.tostr(dbres.writeErrors))
		return false
	end

	return true
end

function command.get_pay_order(order_id)
	assert(order_id)
	local collname = mongo_coll_gen.pay_order()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne({order_id = order_id})

	return dbres
end

function command.get_pay_order_by_tid(transaction_id, plat_id)
	assert(transaction_id and plat_id)
	local collname = mongo_coll_gen.pay_order()
	local coll = _self.get_mongo_coll(collname)
	local args = {
		transaction_id = transaction_id,
		plat_id = plat_id,
	}
	local dbres = coll:findOne(args)

	return dbres
end

function command.finish_pay_order(order_id, transaction_id, status)
	assert(order_id and transaction_id and status)
	local collname = mongo_coll_gen.pay_order()
	local coll = _self.get_mongo_coll(collname)
	local condition = {
		order_id = order_id,
		result = const.excharge_result.create,
	}
	local update_args = {
		["$set"] = {
			result = const.excharge_result.finish,
			transaction_id = transaction_id,
			status = status,
		}
	}
	local dbres = coll:safe_update(condition, update_args)
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("finish_pay_order fail, dbres = %s, condition = %s, kv = %s", 
			futil.tostr(dbres), futil.toStr(condition), futil.tostr(update_args))
		return false
	end

	return true
end

function command.get_waiting_pay_order_by_uid(uid, plat_id)
	assert(uid and plat_id)
	local args = {
		uid = uid,
		plat_id = plat_id,
		result = const.excharge_result.create,		
	}
	local collname = mongo_coll_gen.pay_order()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:find(args):sort({order_id = -1}):limit(10)
	local ret = {}
	
	while dbres and dbres:hasNext() do
		local tmp = dbres:next()
		tmp["_id"] = nil
		ret[#ret+1] = tmp
	end

	return ret
end

function command.update_sms_verify_code(phone, code)
	local expire_time = const.sms_verify.expire or 600
	local rkey = keygen.sms_verify(phone)
	local dbres = redisdb_single:set(rkey, code, 'ex', expire_time)
	if dbres ~= "OK" then
		return false
	end
	return true
end

function command.load_sms_verify_code(phone)
	local rkey = keygen.sms_verify(phone)
	local code = redisdb_single:get(rkey)
	return code
end

function command.update_outer_bind(account_plat, outerid, kvs)
	assert(account_plat and outerid and kvs and next(kvs))
	if not const.account_plat[account_plat] then
		error(string.format("not support account_plat: %s", account_plat))
	end
	local collname = mongo_coll_gen.outerbind(account_plat)
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:safe_update({_id = outerid}, {["$set"] = kvs})
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("update_outer_bind fail, dbres = %s, args = %s, %s, %s", 
			futil.tostr(dbres), account_plat, outerid, futil.tostr(kvs))
		return false
	end
	return true
end

function command.del_verify_code(phone)
	local res = redisdb_single:del(keygen.sms_verify(phone))
	return res
end

function command.create_pay_order_trans(order_id, uid, product, diamond, plat_id)
	assert(uid and order_id and product and diamond and plat_id)
	local collname = mongo_coll_gen.pay_order_trans()
	local coll = _self.get_mongo_coll(collname)
	local args = {
		order_id = order_id,
		uid = uid,
		product = product,
		diamond = diamond,		
		plat_id = plat_id,
	}
	local dbres = coll:safe_insert(args)
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("create_pay_order_trans fail, args = %s, errmsg = %s", 
			futil.toStr(args), futil.tostr(dbres.writeErrors))
		return false
	end

	return true
end

function command.get_pay_order_trans(order_id)
	assert(order_id)
	local collname = mongo_coll_gen.pay_order_trans()
	local coll = _self.get_mongo_coll(collname)
	local dbres = coll:findOne({order_id = order_id})
	return dbres
end

function command.delete_pay_order_trans(order_id, uid)
	assert(order_id and uid)
	local collname = mongo_coll_gen.pay_order_trans()
	local coll = _self.get_mongo_coll(collname)	
	coll:delete({order_id = order_id, uid = uid})
end

function command.get_all_pay_order_trans(uid)
	assert(uid)
	local collname = mongo_coll_gen.pay_order_trans()
	local coll = _self.get_mongo_coll(collname)	
	local dbres = coll:find({uid = uid}):limit(10)
	local ret = {}
	while dbres and dbres:hasNext() do
		local tmp = dbres:next()
		tmp["_id"] = nil
		ret[#ret+1] = tmp
	end

	return ret
end

function command.get_room_list(cond, start_pos, cnt)
	start_pos = start_pos or 0
	cnt = cnt or 1000
	local ret = {}
	local coll = _self.get_mongo_coll(mongo_coll_gen.room_list())
	local dbres = coll:find(cond)
	local tot_cnt = dbres:count()
	dbres = dbres:skip(start_pos):limit(cnt)
	while dbres and dbres:hasNext() do
		local tmp = dbres:next()
		local item = {
			room_id = math.tointeger(tmp._id),
			doll_id = math.tointeger(tmp.doll_id),
			room_type = math.tointeger(tmp.room_type),
			play_cost = math.tointeger(tmp.play_cost),
			mgr_status = math.tointeger(tmp.mgr_status),
			round_time = math.tointeger(tmp.round_time),
			ad = math.tointeger(tmp.ad),
			gm_status = math.tointeger(tmp.gm_status),
			creator_account = tmp.creator_account,
			create_time = math.tointeger(tmp.create_time),
			running_status = math.tointeger(tmp.running_status),
			now_wawaji_id = math.tointeger(tmp.now_wawaji_id),
		}
		table.insert(ret, tmp)
	end

	return ret, tot_cnt
end

-- 设置idip请求锁
function command.get_idip_req_lock(key, val, expire)
	local rkey = keygen.idip_req_lock(key)
	local r = command.redis_eval_try_sha(redisdb_single, util_redis_script.test_and_get, util_redis_script.test_and_get_sha, 
		1, rkey, expire, val)
	if r ~= "OK" then
		return false
	end	
	return true
end

-- 释放idip请求锁
function command.delete_idip_req_lock(key, val)
	local rkey = keygen.idip_req_lock(key)
	command.redis_eval_try_sha(redisdb_single, util_redis_script.test_and_del, util_redis_script.test_and_del_sha, 
		1, rkey, val)
	return true
end

function command.write_user_play_result(kvs)
	local coll = _self.get_mongo_coll(mongo_coll_gen.user_play_result())
	local dbres = coll:safe_insert(kvs)
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("write_user_play_result fail, dbres = %s, args = %s", futil.tostr(dbres), futil.tostr(kvs))
		return false
	end
	return true
end


function command.update_user_ban_info(uid, doc_name, info_change)
	assert(uid and type(uid) == "number" and doc_name and next(info_change))
	local kvs = {}
	for k, v in pairs (info_change) do
		local key = string.format("%s.%s", doc_name, k)
		kvs[key] = v
	end
	local coll = _self.get_mongo_coll(mongo_coll_gen.user_basic())
	local dbres = coll:safe_update( {_id = uid}, {["$set"] = kvs})
	if not (dbres and dbres.ok == 1 and dbres.n == 1) then
		logger.err("update_user_ban_info fail, dbres = %s, uid = %s, kv = %s", futil.tostr(dbres), uid, futil.tostr(kvs))
		return false
	end
	return true
end


local function reg_handler()
	-- 使用common/data_handler/data_example_handler.lua自定义
	local handlers = {
		"data_handler.data_backpack",
		"data_handler.data_sys_mail",
		--"data_handler.data_friend",
		"sql_data_handler.sql_data_backpack",
		"sql_data_handler.sql_data_userbasic",
		"sql_data_handler.sql_data_userbind",
		"sql_data_handler.sql_data_outerbind",
		"sql_data_handler.sql_data_pay_order",
		"sql_data_handler.sql_data_pay_order_trans",
		"sql_data_handler.sql_data_friend",
		"sql_data_handler.sql_data_open_info",
		"sql_data_handler.sql_data_sys_mail",
		"sql_data_handler.sql_data_fish_machine_info",
		"sql_data_handler.sql_data_player_login_log",--include machine_login_log
		
	}

	for _, file in ipairs(handlers) do
		local handler = require(file)
		handler.reg(_self, command)
	end
end


--mysql_mydataworker.reg(command)

skynet.init(function()
	const = query_sharedata "const"
	globalconf = query_sharedata "globalconf"
end)

skynet.start(function()
	--check args
	if not _self.workernum then
		error("dataworker, invalid _self.workernum, should not be nil")
	end
	_self.serviceName = string.format(".dataworker%d", _self.workernum)
	logger.info("%s starting...", _self.serviceName)

	skynet.dispatch("lua", function(session, address, cmd, ...)
		cmd = string.lower(cmd)
		local sTime = skynet.time()
		profile.start()
		local ok, err = xpcall(skynet_util.lua_docmd, skynet_util.handle_err,
			command, session, cmd, ...)
		if not ok then
			skynet.error(_self.serviceName, ", error, args = ", 
				session, address, cmd, table.tostring({...}))
			cmdStat:stat(cmd, sTime, skynet.time(), profile.stop(), address)
			-- ensure skynet ret
			error(err)
		end
		cmdStat:stat(cmd, sTime, skynet.time(), profile.stop(), address)
	end)


	----redisdb
	--已经建立连接的redis {{db=xx,host="xx",port="xx"}, ...}
	local connected_redis_db = {} 
	--单实例redis connect
	redisdb_single = _self.make_redis_conn(_conf.redis_host_single, _conf.redis_port_single, _conf.redis_auth_single, connected_redis_db) 
	--rank redis connect
	rank_redisdb_arr[1] = _self.make_redis_conn(_conf.rank_redis_host1, _conf.rank_redis_port1, _conf.rank_redis_auth1, connected_redis_db)
	rank_redisdb_arr[2] = _self.make_redis_conn(_conf.rank_redis_host2, _conf.rank_redis_port2, _conf.rank_redis_auth2, connected_redis_db)
	rank_redisdb_arr[3] = _self.make_redis_conn(_conf.rank_redis_host3, _conf.rank_redis_port3, _conf.rank_redis_auth3, connected_redis_db)
	--alias of rank redisdb
	rankdb.test_rank_redisdb = rank_redisdb_arr[const.ranktype_2_rankredis.test_rank]


	----mongodb
	-- mongoc = mongo.client({
	-- 	host = _conf.mongo_host,
	-- 	port = _conf.mongo_port 
	-- })
	-- mongo_fish3d = mongoc:getDB(_conf.mongo_dbname)

	gamedb = _self.make_mysql_conn(_conf.mysql_host, _conf.mysql_port, _conf.db_game,
    		_conf.mysql_user, _conf.mysql_pwd, 1024*1024)

	reg_handler()

	skynet.info_func(function()
		return string.format("DATAWORKER STAT: \n%s\nDATAWORKER MISS STAT: \n%s", 
			cmdStat:str(), futil.toStr(_self.fuzzy_stat))
	end)
	skynet.register(_self.serviceName)
	skynet.fork(_self.autoPrintStat)
	--skynet.fork(_self.make_sure_mongo_index)
	logger.info("%s  by dataworkerdotlua started", _self.serviceName)
end)
