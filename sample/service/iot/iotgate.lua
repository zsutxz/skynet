local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local packer = require "packer"
local service = require "service"
local proxy = require "socket_proxy"
local logger = require "logger"
local cache_util = require "cache_util"

local iotgate = {}
local data = {}


local function auth_package(fd)
	return skynet.call(service.iotauth, "lua", "shakehand" , fd)
end

local function assign_agent(fd,mach,pos)
	skynet.call(service.iotmanager, "lua", "assign", fd, mach,pos)
end

local function new_package(fd, addr)
	logger.info(string.format("%s iot connected as %d" , addr, fd))

	proxy.subscribe(fd)

	local ok,mach,pos = pcall(auth_package, fd)
	
	if ok and mach ~= nil then
		--logger.info(string.format("auth_package result:%s,mach:%s pos:%s,fd:%d", ok,mach,pos,fd))

		if pcall(assign_agent, fd, mach,pos) then
			return	-- succ
		else
			logger.info(string.format("Assign failed %s to %s,pos:%s", addr, mach,pos))
		end
	end
end

function connect_db()
	skynet.timeout(30*60*100, connect_db)
	logger.info("connect to mysql db")
	local res = cache_util.call('wx_db', 'select_max_machid', {})
end

function iotgate.open(ip, port)
	assert(data.fd == nil, "Already open")
	skynet.error("Listen iot socket ", ip, port)
	data.fd = socket.listen(ip, port)
	data.ip = ip
	data.port = port
	socket.start(data.fd, new_package)

	skynet.timeout(30*60*100, connect_db)
end

function iotgate.close()
	assert(data.fd)
	skynet.error("Close %s:%d", data.ip, data.port)
	socket.close(data.fd)
	data.ip = nil
	data.port = nil
end

service.init {
	command = iotgate,
	info = data,
	require = {
		"iotauth",
		"iotmanager",
	}
}
