local skynet = require "skynet"
require "skynet.manager"
local socket = require "socket"
local logger = require "logger"
local const = require "const"
local futil = require "futil"
local skynet_util = require "skynet_util"

local managePort = skynet.getenv("manageport")
local nodename = skynet.getenv "nodename"
local nodeFullName = skynet.getenv "nodeFullName"

local SOCKET = {}
local CMD = {}
local serverStatus = const.server_status.initing

local get_service
local get_service_list
local get_service_match
local needReloadServices = {
}

--命令限制，有些命令只能在特定服务器执行
local cmd_limit = {
	kick = {
		plazaserver = true,
		fishmachineserver = true,
	},
	find = {
		plazaserver = true,
		fishmachineserver = true,
	},
}

local function is_cmd_limit(cmd)
	local svrname = futil.get_svrname_by_nodename(nodename)
	if cmd_limit[cmd] and (not cmd_limit[cmd][svrname]) then
		return true
	end
	return false
end

local function adjust_address(address)
	if address:sub(1,1) ~= ":" then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result,"\t")
end

local function dump_line(print, key, value)
	if type(value) == "table" then
		print(key, format_table(value))
	else
		print(key,tostring(value))
	end
end

local function dump_list(print, list)
	local index = {}
	for k in pairs(list) do
		table.insert(index, k)
	end
	table.sort(index)
	for _,v in ipairs(index) do
		dump_line(print, v, list[v])
	end
	print("OK")
end

local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local function docmd(cmdline, print)
	local split = split_cmdline(cmdline)
	local cmd = split[1]
	local cmdfunc = SOCKET[cmd]
	local ok, list
	if cmdfunc then
		if is_cmd_limit(cmd) then
			ok = false
			list = "not allow this cmd"
		else
			ok, list = pcall(cmdfunc, select(2,table.unpack(split)))
		end
	else 
		list = "invalid cmd"
	end

	if ok then
		if list then
			if type(list) == "string" then
				print(list)
			else
				dump_list(print, list)
			end
		else
			print("OK")
		end
	else
		print("Error:", list)
	end
end

local function console_main_loop(stdin, print)
	socket.lock(stdin)
	print("Welcome to skynet manage console")
	while true do
		local cmdline = socket.readline(stdin, "\n")
		if not cmdline then
			break
		end
		if cmdline ~= "" then
			docmd(cmdline, print)
		end
	end
	socket.unlock(stdin)
end

local function getStatInfo()
	logger.info("getStatInfo")

	local ok, watchdog_res = pcall(skynet.call, ".watchdog", "lua", "get_stat")
	if not ok then 
		logger.err('getStatInfo, .watchdog fail, error = %s', watchdog_res)
	end	

	local ok, login_res = pcall(skynet.call, ".login", "lua", "get_stat")
	if not ok then 
		logger.err('getStatInfo, .login fail, error = %s', login_res) 
	end

	local info = {watchdog = watchdog_res, login = login_res}
	logger.info("getStatInfo finish")
	return info
end


function SOCKET.help()
	return {
		help 		= "This help message",
		kick 		= "kick openid kick_msg: kick user, if openid = -1, kick all user, kick_msg can be null",
		ss 		= "ss status : set server status, 1=init,2=running,3=maintain",
		status 		= "show nodename and status, e.g. 'gameserver_QA_qq_1 2', 1=initing,2=running,3=maintaining",
		stat 		= "stat: show server stat",
		memstat     	= "memstat: show memory stat",
		sloglvl 		= [[sloglvl level interval filesize : level(debug/info/warn/err/fatal)
						interval(date/hour), filesize(a number)]],
		reload      	= "reload [loglvl] : reload conf or loglvl(if given)",
		find		= "find -u uid/-n nickname/-o openid: to find user, especially when -u -1 will get all user",
		list		= "list service, support \"list pos num\"",
		mem			= "list service with memory, support \"mem pos num\"",
		sinfo       	= "output server info",
		info        	= "info address : show service info"
	}
end

local coreService = {
	["snlua cdummy"] = true,
	["snlua datacenterd"] = true,
	["snlua service_mgr"] = true,
	["snlua lkclusterd"] = true,
	["snlua logservice"] = true,
	["snlua gate"] = true,
	["snlua debug_console"] = true,
	["snlua sharedatad"] = true,
	["snlua protoloader"] = true,
	["snlua configsloader"] = true,
	["snlua constloader"] = true,
}

local function isCoreService(name)
	if coreService[name] then
		return true
	end
	
	for k, _ in pairs(coreService) do
		if string.find(name, k) then
			return true
		end
	end

	return false
end

function SOCKET.test_login(machine_id, posi, account_plat, player_id)
	logger.info("test_login machine_id = %s, posi = %s, account_plat=%s, player_id = %s", 
		machine_id, posi , account_plat, player_id)
	local ok, res = pcall(skynet.call, ".watchdog", "lua", "on_player_login", tonumber(machine_id), tonumber(posi), account_plat, player_id)
	if not ok then
		logger.info("call fail")
		return "call fail"
	end
	if not res then
		logger.info("on_player_login fail")
		return "on_player_login fail"
	end
	return "login_ok"
end

function SOCKET.sloglvl(level, rollInterval, max_log_file_size)
	logger.info("mc, sloglvl, level = %s, rollInterval = %s, max_log_file_size = %s, type(max_log_file_size) = %s", 
		level, rollInterval, max_log_file_size, type(max_log_file_size))
	
	--check args
	if not const.log_level[level] then
		logger.err("mc, sloglvl, invalid level = %s", level)
		return "invalid log level"
	end

	if rollInterval and const.rolling_type[rollInterval] == nil then
		logger.err("mc, sloglvl, invalid rolling_type = %s", rollInterval)
		rollInterval = nil
	end

	--reload logservice
	local ok, res = pcall(skynet.call, ".logservice", "lua", "set_log_level", level)
	if not ok then
		logger.err("mc, sloglvl fail, logservice set_log_level error, error = %s", res)
		return "fail"
	end
	logger.info("mc, sloglvl, logservice set_log_level res = %s", futil.toStr(res))

	if rollInterval then
		local ok, res = pcall(skynet.call, ".logservice", "lua", "set_roll_interval", rollInterval)
		if ok then
			logger.info("mc, sloglvl, logservice set_roll_interval res = %s", futil.toStr(res))
		end
	end

	local nsize = tonumber(max_log_file_size)
	if nsize then
		local ok, res = pcall(skynet.call, ".logservice", "lua", "set_max_log_file_size", nsize)
		if ok then
			logger.info("mc, sloglvl, logservice set_max_log_file_size res = %s", futil.toStr(res))
		end
	end

	--reload every logger
	local ok, serviceList = pcall(skynet.call,".launcher","lua", "LIST")
	if not ok then
		logger.err("mc, sloglvl fail, get service list error, error = %s", serviceList)
		return "fail"
	end
	for k, v in pairs(serviceList) do
		if not isCoreService(v) then
			skynet.send(k, "log", "set_log_level", level)
		end
	end
	
	logger.info("mc, sloglvl finish")
	return "ok"
end

function SOCKET.status()
	return string.format("%s %s", nodename, serverStatus)
end

function SOCKET.ss(arg)
	logger.info('mc, ss %s', arg)

	local status = tonumber(arg)
	if not status then
		logger.err("mc, ss fail, invalid status: %s", arg)
		return "invalid status"
	end

	local found = false
	for k, v in pairs(const.server_status) do
		if status == v then
			found = true
			break
		end
	end
	if not found then
		logger.err("mc, ss fail, invalid status: %s", arg)
		return "invalid status"
	end

	local ok, res = pcall(skynet.call, ".watchdog", "lua", "set_server_status", status)
	if not ok then
		logger.err('mc, ss fail, status = %s, error = %s', arg, res)
		return 'fail'
	end
	if not res.ok then
		logger.err('mc, ss fail, status = %s', arg)
		return 'fail'
	end

	--success, set the env
	serverStatus = status
	logger.info('mc, ss finish')
	return 'ok'
end

function SOCKET.kick(openid, reason, kick_msg)
	logger.info("mc, kick, args = %s, %s, %s", openid, reason, kick_msg)
	reason = tonumber(reason)

	openid = math.tointeger(openid)
	if kick_msg == "" then kick_msg = nil end
	local retMsg = "ok"

	if openid ~= -1 then
		--kick one user
		if not reason then
			reason = const.kick_reason.admin_kick
		end
		local ok, ret = pcall(skynet.call, ".watchdog", "lua", "kick_by_openid", openid, reason, kick_msg)
		if not ok then
			retMsg = string.format("kick_by_openid fail, ret = %s, openid = %s", ret, openid)
		elseif not ret or ret.error_code ~= const.kick_user_errorcode.ok then
			retMsg = string.format("kick_by_openid fail, ret = %s, openid = %s", futil.toStr(ret), openid)
		end
	else
		--kick all user
		if not reason then
			reason = const.kick_reason.server_is_shutdowning
		end
		local ok, ret = pcall(skynet.call, ".watchdog", "lua", "kick_all_user", reason, kick_msg) 
		if not ok then
			retMsg = string.format("kick_all_user fail, ret = %s", futil.toStr(ret))
		end
		if not ret.ok then
			retMsg = string.format("kick_all_user fail, needKickCnt = %s, kickedCnt = %s", 
				ret.needKickCnt, ret.kickedCnt)
		end
	end
	logger.info("mc, kick result: %s", retMsg)
	return retMsg
end

function SOCKET.stat()
	local info = futil.toStr(getStatInfo())
	return info
end

function SOCKET.memstat()
	local ok, mem_stat = pcall(skynet.call, ".profiler", "lua", "get_stat")
	if not ok then
		logger.err('memstat fail, error = %s', mem_stat)
	end
	local info = futil.toStr(mem_stat)
	return info
end

local function get_service_list(start, num)
	local ok, list = pcall(skynet.call, ".launcher", "lua", "LIST")
	if not (ok and list) then
		logger.err("get_service_list fail, error = %s", list)
		return false, list
	end	
	local ret = {}
	local cnt = 0
	local sortdata = {}
	for k, v in pairs(list) do
		local handle = skynet_util.string_to_handle(k)
		table.insert(sortdata, {handle = handle, val = v})
	end
	table.sort(sortdata, function (a,b) return a.handle < b.handle end)
	for _, v in ipairs(sortdata) do
		if num ~= -1 and cnt >= num then
			break
		end	
		if v.handle >= start then
			ret[v.handle] = v.val
			cnt = cnt + 1
		end	
	end
	return true, ret
end

function SOCKET.list(start, num)
	start = tonumber(start)
	num = tonumber(num)
	if not start then start = 0 end
	if not num then num = -1 end

	local ok, list = get_service_list(start, num)
	if not ok then
		return string.format("fail, error = %s", list)
	end
	local ret = {}
	for k, v in pairs(list) do
		ret[skynet.address(k)] = v
	end
	return ret
end

function SOCKET.mem(start, num)
	start = tonumber(start)
	num = tonumber(num)
	if not start then start = 0 end
	if not num then num = -1 end

	local ok, list = get_service_list(start, num)
	if not ok then
		return string.format("fail, error = %s", list)
	end
	local ret = {}
	for k, v in pairs(list) do
		local addr = skynet.address(k)
		local ok, mem = skynet_util.timeout_call(2*100, addr, "debug", "MEM")
		if ok and mem then
			ret[addr] = string.format("%.2f Kb (%s)", mem, v)
		else
			ret[addr] = string.format("Error (%s)", v)
			logger.err("get mem fail, addr = %s, name = %s, error = %s", addr, v, mem)
		end
	end
	return ret
end

function SOCKET.sinfo()
	local ret = {nodename = nodename, 
		log_level = const.log_lvlstr[logger.get_log_level()],
	}
	return futil.toStr(ret)
end

function SOCKET.info(address, ...)
	if not address then
		return "invalid address"
	end
	address = adjust_address(address)
	return skynet.call(address,"debug","INFO", ...)
end

function SOCKET.test()
	print("test")
	logger.debug("debug")
	logger.info("info")
	logger.warn("warn")
	logger.err("err")
	logger.fatal("fatal")

	--run dataworker test
	logger.err("!! run dataworker test !!")
	skynet.send(".dataworker0", "lua", "test")
end

function SOCKET.test2(doll_id)
	--print("test2")
	--run dataworker test
	logger.info("data worker test2")
	skynet.send(".dataworker0", "lua", "mysql_get_doll_info",  doll_id)
end

function SOCKET.test3()
	--print("test2")
	--run dataworker test
	logger.info("data worker test3")
	skynet.send(".dataworker0", "lua", "mysql_get_all_doll")
end

function SOCKET.test4(uid)
	--print("test4")
	--run dataworker test
	logger.info("data worker test4")
	skynet.send(".dataworker0", "lua", "mysql_load_backpack", uid)
end

function SOCKET.test5(uid, data)
	--print("test5")
	--run dataworker test
	logger.info("data worker test5")
	skynet.send(".dataworker0", "lua", "mysql_update_backpack", uid, data)
end

function SOCKET.log(lvl, msg)
	lvl = tonumber(lvl)
	if lvl == const.log_level.debug then
		logger.debug(msg)
	elseif lvl == const.log_level.info then
		logger.info(msg)
	elseif lvl == const.log_level.warn then
		logger.warn(msg)
	elseif lvl == const.log_level.err then
		logger.err(msg)
	else
		return "invalid lvl"
	end

	return "ok"
end

function SOCKET.find(t, arg)
	local res
	if t == "-u" then
		local uid = math.tointeger(arg)
		res = skynet.call(".watchdog", "lua", "find_by_uid", uid)
	elseif t == "-n" then
		local nickname = arg
		res = skynet.call(".watchdog", "lua", "find_by_nickname", nickname)
	elseif t == "-o" then
		local openid = math.tointeger(arg)
		res = skynet.call(".watchdog", "lua", "find_by_openid", openid)
	else
		return "invalid arg"
	end
	return res or "no user"
end

local function reloadConf(cfg)
	if cfg then
		if cfg == '' or cfg == 'nil' then
			cfg = nil
		else
			cfg = string.format(".%sloader", cfg)
		end
	end

	local msg = ''
	local succ = true
	for serviceName in pairs(needReloadServices) do
		if not cfg or cfg == serviceName then
			logger.info('will reload %s', serviceName)
			local ok, ret = pcall(skynet.call, serviceName, "lua", "reload")
			if ok then
				msg = msg..string.format("%s succ;", serviceName)
			else
				succ = false
				msg = msg..string.format("%s fail, err:%s;", serviceName, ret)
			end
		end
	end
	logger.info('reloadConf result, succ = %s, msg = %s', succ, msg)
	return succ, msg
end

function SOCKET.reload(logLvl, cfg, logRollInterval, max_log_file_size)
	logger.info("mc, reload, loglvl = %s, cfg = %s, rollInterval = %s, max_log_file_size = %s", 
		logLvl, cfg, logRollInterval, max_log_file_size)

	--reload conf
	local reloadConfSucc, reloadConfMsg = reloadConf(cfg)
	if not reloadConfSucc then
		return reloadConfMsg
	end

	--reload log level
	if logLvl and logLvl ~= "" and logLvl ~= "current" then
		local reloadLogSucc = SOCKET.sloglvl(logLvl, logRollInterval, max_log_file_size)
		if reloadLogSucc ~= "ok" then
			return reloadLogSucc
		end
	end

	logger.info("mc, reload finish")
	return "ok"
end


function SOCKET.stop_cluster()
	logger.info("mc, stop_cluster")

	local ok, err = pcall(skynet.call, ".clustermgr", "lua", "stop_cluster")
	pcall(skynet.call, ".tlogc", "lua", "on_stop")
	pcall(skynet.call, ".tss", "lua", "exit")
	if not ok then
		logger.err('mc, stop_cluster fail, error = %s', err)
		return string.format("fail, error = %s", err)
	end

	logger.info('mc, stop_cluster finish')
	return 'ok'
end

function CMD.register_reload_service(serviceName)
	logger.info("manageconsole, register_reload_service: %s", serviceName)
	needReloadServices[serviceName] = true
end

function CMD.unregister_reload_service(serviceName)
	logger.info("manageconsole, unregister_reload_service: %s", serviceName)
	needReloadServices[serviceName] = nil
end

function CMD.set_server_status(status)
	serverStatus = status
	logger.info("manageconsole set_server_status: %s", status)
end

skynet.start(function()
	--for inside cmd
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[string.lower(cmd)]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.error("manage_console, Unknown CMD :", tostring(cmd))
		end
	end)

	--for outer cmd
	logger.info("managePort = %s", managePort)
	if managePort and managePort ~= 0 then
		local ok, listen_socket = pcall(socket.listen, "127.0.0.1", managePort)
		if not ok then
			local errMsg = string.format("listen_error:port=%s,name=manageport", managePort)
			logger.err(errMsg)
			skynet.error(errMsg)
			error(listen_socket)
		end
		logger.info("manage_console listen at 127.0.0.1:" .. managePort)
		socket.start(listen_socket , function(id, addr)
			local function print(...)
				local t = { ... }
				for k,v in ipairs(t) do
					t[k] = tostring(v)
				end
				socket.write(id, table.concat(t,"\t"))
				socket.write(id, "\n")
			end
			socket.start(id)
			skynet.fork(console_main_loop, id , print)
		end)
	end

	skynet.register(".manage_console")
	logger.info("manage_console started")
end)