local skynet = require "skynet"
local service = require "service"
local logger = require "logger"
local iotmanager = {}

--在线fd对应的agent
local online_fd_agent = {}

local function new_agent()
	-- todo: use a pool
	return skynet.newservice "iotagent"
end

local function free_agent(agent)
	-- kill agent, todo: put it into a pool maybe better
	skynet.kill(agent)
end

function iotmanager.assign(fd,mach,pos)
	local agent = nil
	repeat
		agent = online_fd_agent[fd]

		--fd上新分配一个agnent，同时需要在until中赋值。
		if not agent then
			agent = new_agent()
			if not online_fd_agent[fd] then
				-- double check
				online_fd_agent[fd] = agent
			else
				free_agent(agent)
				agent = online_fd_agent[fd]
			end
			logger.info("in iotmanager Assign 0x%x to %s ", agent, fd)
		else			
			--fd上已经有机器（agent），另外一个机器加入
			local ret = skynet.call(agent, "lua", "add", fd,mach,pos)
			if ret then
				break
			end
		end
	until skynet.call(agent, "lua", "assign", fd,mach,pos)
	return true
end

function iotmanager.getagent(mach,pos)

	local fd = skynet.call(service.iotauth,"lua","getauthfd",mach,pos)
	
	if fd~=nil and online_fd_agent[fd]~=nil then
		--logger.info("getagent  mach:%s,pos:%s,fd:%s",mach,pos,fd)
		return online_fd_agent[fd]
	else
		return nil 
	end
end

--fd agent上有已经有人登录,使用本方法
function iotmanager.iotlogin(args)
	local mach,pos = skynet.call(service.iotauth, "lua", "login", args.fd,args.session_str,args.msg)
	
	return mach,pos
end

--清除mach..pos的登录信息
function iotmanager.clearmachpos(fd,mach,pos)

	--logger.info("in iotmanager.clearmachpos: %s",mach..pos)

	--清除服务器与iot端的连接信息，
	skynet.call(service.iotauth, "lua", "clearmachpos",fd, mach,pos)
	return true
end

service.init {
	command = iotmanager,
	info = nil,
	require = {
		"iotauth",
		"wechathttpc",
	},
}


