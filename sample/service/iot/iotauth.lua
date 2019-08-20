local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local packer = require "packer"
local print_t = require "print_t"
local cache_util = require "cache_util"
local sqlutil = require "sqlutil"
local service = require "service"
local des_encrypt = require "des_encrypt"
local logger = require "logger"

--iot登录成功的机台卡位对应的fd
local auth_machpos_fd = {}

local CMD = {}
local iotauth = {}

local function read(fd)
	return skynet.tostring(proxy.read(fd))
end

local function write(fd,str)
	proxy.write(fd,str)
end

local function register(game,machid)
	
	local game = tonumber(game)
	local machid = tonumber(machid)

	--先查询是否已经有记录
	local sqlarg = {game = game, machid = machid}
	local res = cache_util.call('wx_db', 'load_machine_info', sqlarg)
	
	if not res then
	    logger.err("load_machine_info sql err")
        return {errmsg = 'DB error',errcode = 2}
	end

	if #res ~= 1 then
		print("register insert_machine")
		sqlarg = {game = game, machid = machid,company = 0,store = 0,locked = 0,time = os.date("%Y%m%d%H%M%S", os.time()),desc = "test"}
    	res = cache_util.call('wx_db', 'insert_machine', sqlarg)

		if res then
			print("register machine ok!")
		 	return {errmsg = 'write db ok',errcode = 0}
		end
    end

	print("user have registered!")
	return {errmsg = 'user have registered',errcode = 1}
end

--注册的时候，从数据库获取最大的machid
local function get_next_machid()
	local sqlarg = {}
	local next_id
	local res = cache_util.call('wx_db', 'select_max_machid', sqlarg)

	if not res then
		logger.err("select_max_machid sql err")
		return nil
	end
		
	if #res == 1 and res[1] ~= nil and res[1].max_id then
	   	--print("res.max_id:"..res[1].max_id)
		next_id = res[1].max_id + 1
	else
		next_id = 1
	end

	local next_id_str = tostring(next_id)
	local str_len = #next_id_str
	for i=1,6 - str_len,1 do
		next_id_str = "0"..next_id_str
	end
	return next_id_str
end

--检测登录信息
local function check_login(fd,game,machid,pos)
	local ret = {errcode = "unkown_error"}

	local mach = game..machid

	--篮球机一个设备只有一个卡位，但是连到android后，android会发给可变的卡位号过来，
	--所以卡位号干脆统一设置为“00”,相当于在随后的在线机器处理中，不使用卡位。
	if game == "106" then
		pos = "00"
	end

	--108是安卓路由器，返回成功
	if game == "108" then
		ret.errcode = 4
		ret.errmsg = "android mach"
	elseif auth_machpos_fd[mach..pos] ~= fd then

		local sqlarg = {game = game, machid = machid}
		local res = cache_util.call('wx_db', 'load_machine_info', sqlarg)

		if not res then
			logger.err("load_machine_info sql err")
			return {errmsg = 'DB error',errcode = 2}
		end
		
		if #res ~= 1 then
			ret.errcode = 3
			ret.errmsg = 'machine not found'
			return ret
		end

		auth_machpos_fd[mach..pos] = fd

		logger.info("in login, machpos:%s,fd:%d",mach..pos,auth_machpos_fd[mach..pos])

		ret.errcode = 0
		ret.errmsg = "login ok"
	else
		ret.errcode = 1
		ret.errmsg = "login again:"..mach..pos
	end

	return ret
end

function iotauth.login(fd,session_str,msg)
	--转换为字符串
	local pos = (math.floor(string.byte(msg,1,1)/10))..(math.floor(string.byte(msg,1,1)%10))
	local game = string.sub(msg,2,4)
	local machid = string.sub(msg,5,10)

	local ret = check_login(fd,game,machid,pos)
	
	--登录成功
	if ret.errcode==0 then
		local retstr  = string.char(math.random(0,255))..string.char(math.random(0,255))

		--数据种类，sssion，返回值
		retstr = retstr..string.char(12)..session_str..string.char(tonumber(pos))..string.char(1)
	
		--local enstr = retstr
		local len, enstr = des_encrypt.iot_encode(retstr)
		--数据长度，底层的proxy.write()会自动加入
		write(fd,enstr)

		logger.info("in iotauth.login %s(%s)login ok!",game..machid,pos)
		return game..machid,pos
	elseif ret.errcode == 4 then
		--安卓设备登录，暂时不处理
		logger.info("iot login:android mach login! ")
	else 	--新机器，需要注册
		print("login err:"..ret.errcode.." "..ret.errmsg)
		--print("no registger:"..ret.errcode)
		-- for i=1,6,1 do
		-- 	print(i..": "..tonumber(string.sub(machid,i,i)).." ")			
		-- 	if string.sub(machid,i,i)~=nil and tonumber(string.sub(machid,i,i))~=0 then
		-- 		new_flag = 0
		-- 	end
		-- end
		local machid_n = tonumber(machid)
		
		--序列号为全0
		if machid_n == 0 then
			game = "106"

			machid = get_next_machid()
			if machid == nil then
				machid = "000000"
			end
			
			local ret = register(game,machid)	
			if ret.errcode==0 then
				local retstr  = string.char(math.random(0,255))..string.char(math.random(0,255))

				--设置成功，发10号命令给机台
				--数据种类,sssion,设置值
				retstr = retstr..string.char(10)..session_str..string.char(tonumber(pos))..game..machid

				local len, enstr = des_encrypt.iot_encode(retstr)
				write(fd,enstr)

				print("new iot register "..machid.." restart machine")
			else
				print("register error:"..ret.errmsg)
			end
		end	
	end
end

function iotauth.shakehand(fd)
    
	proxy.subscribe(fd) 	

	while true do
		local ok, s = pcall(read, fd)
		if not ok then
			skynet.error("CLOSE")
			break
		end

		logger.info("auth I receive, data:%s,lenght:%d",s,#s)
		
		-- for i=1,#s,1 do
		-- 	print(string.format("%04X",string.byte(s, i, i)))
		-- end

		-- local destr = s	 
		-- local len,enstr = des_encrypt.iot_encode("vMp12341106000001")	
		-- print("enstr:"..len.."  "..enstr)
		-- local len, destr = des_encrypt.iot_decode(string.sub(enstr, 3, -1))
		-- print("destr:"..len.."  "..destr)
		
		local len,destr = des_encrypt.iot_decode(s)

		local kind = string.byte(destr,3,3)
		local session_str = string.sub(destr,4,7)
		local msg = string.sub(destr,8,-1)

		logger.info("auth msg,kind:%s,%s,msg:%s",kind,type(kind),msg)

		if kind==112 then			--iot发送登录请求
			return iotauth.login(fd,session_str,msg)
		end
	end
end

function iotauth.getauthfd(mach,pos)
 
 	--logger.info("getauthfd auth_machpos_fd mach:%s,pos:%s",mach,pos)
	
	--机台为篮球机时，不需要使用位置信息，统一为00
	if string.sub(mach,1,3)=="106" then
		pos = "00"
	end

	if auth_machpos_fd ~= nil and  auth_machpos_fd[mach..pos] ~= nil then
		local fd = auth_machpos_fd[mach..pos]
		--logger.info("auth_machpos_fd mach:%s,pos:%s,fd:%d",mach,pos,fd)
		return fd
	end
end

function iotauth.clearmachpos(fd,mach,pos)	
	
	--机台为篮球机时，不需要使用位置信息，统一为00
	if string.sub(mach,1,3)=="106" then
		pos = "00"
	end

	--logger.info("in iotauth.clearmachpos fd:%d,machpos:%s",fd,mach..pos)
	--logger.info("in iotauth.clearmachpos auth_machpos_fd[mach..pos]:%d",auth_machpos_fd[mach..pos])
	
	if auth_machpos_fd[mach..pos]~=nil and auth_machpos_fd[mach..pos] == fd then
		auth_machpos_fd[mach..pos]  = nil
	end

	return true
end

service.init {
	command = iotauth,
		require = {
		"wechathttpc",
	}
}

