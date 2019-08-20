local skynet = require "skynet"
local cache_util = require "cache_util"
local logger = require "logger"

local debugport = tonumber(skynet.getenv("debugport") or '8000')

local logfilename = skynet.getenv("logfilename") or "log"
local dataworkerCnt = tonumber(skynet.getenv("dataworkercnt")) or 3


local function start_debug_console()
	local ok, err = pcall(skynet.newservice, "debug_console", debugport)
	if not ok then
		local errMsg = string.format("listen_error:port=%s,name=debugport", debugport)
		logger.err(errMsg)
		skynet.error(errMsg)		
		error(err)
	end
end

skynet.start(function()
	--logservice should start first
	skynet.newservice("logservice")
   	skynet.call('.logservice', 'lua', 'set_log_file', logfilename)

	skynet.error("Server start")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	
	start_debug_console()
	skynet.newservice("manage_console")

	--foundation service
	skynet.uniqueservice("protoloader")
	skynet.uniqueservice("constloader")
	skynet.uniqueservice("globalconfloader")


	cache_util.init()
	math.randomseed(os.time())
	
	local iotgate = skynet.newservice("iotgate")
	skynet.call(iotgate, "lua", "open", "0.0.0.0", 6666)
	
	local httpserver = skynet.newservice("httpserver")
	
	--skynet.newservice("room_master")
	skynet.newservice("room_manager")

	--register service need reload(注册关联的顺序)
	skynet.call(".manage_console", "lua", "register_reload_service", ".constloader")
	skynet.call(".manage_console", "lua", "register_reload_service", ".globalconfloader")
	skynet.call(".manage_console", "lua", "register_reload_service", ".configsloader")
	skynet.call(".manage_console", "lua", "register_reload_service", ".version_mgr")
	skynet.call(".manage_console", "lua", "register_reload_service", ".whitelist_mgr")
	skynet.call(".manage_console", "lua", "register_reload_service", ".cert_verify")
	skynet.call(".manage_console", "lua", "register_reload_service", ".tlogc")


	-- wechatgate = skynet.newservice("wechatgate")
	-- skynet.call(wechatgate, "lua", "open", "0.0.0.0", 8002)
	
	--skynet.newservice("testwebsocket")
	--skynet.newservice("testdb")
	
	local proto = skynet.uniqueservice "protoloader"
	skynet.call(proto, "lua", "load", {
		"proto.c2s",
		"proto.s2c",
	})
	-- local hub = skynet.uniqueservice "hub"
	-- skynet.call(hub, "lua", "open", "0.0.0.0", 5678)
	skynet.exit()
end)
