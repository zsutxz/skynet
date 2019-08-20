require "skynet.manager"
require "functions"
local skynet = require "skynet"
local skynet_util = require "skynet_util"
local proxy = require "socket_proxy"
local sproto = require "sproto"
local logger = require "logger"
local des_encrypt = require "des_encrypt"
local query_sharedata = require "query_sharedata"

local print_t = require "print_t"

local const = {}
local message = {}
local var = {
	fd = 0,
	session_id = 0 ,
	session = {},
	object = {},
	last_t = 0,
	agent_last_t = 0,
}

local function read(fd)
	return skynet.tostring(proxy.read(fd))
end

local function write(fd,str)
	proxy.write(fd,str)
end

function message.bind(obj, handler)
	var.object[obj] = handler
end

--服务器向iot发送信息
function message.send(name,args)
	local session_id = nil

	if args.session_id==nil then
		var.session_id = var.session_id + 1
		if var.session_id>2000000000 then
			var.session_id = 1
		end

		session_id = var.session_id
		var.session[var.session_id] = { name = name,req = args }
	else
	 	session_id = args.session_id
	end

	logger.info("iotmessage send,name:%s,fd:%d,kind:%s,session_id:%d",name,var.fd,args.kind,session_id)

	local reqstr  = string.char(math.random(0,255))..string.char(math.random(0,255))
	--数据种类
	reqstr = reqstr..string.char(tonumber(args.kind))
	--session_id
	local tempa = math.floor(session_id/(256*256*256))
	local tempb = math.floor(session_id/(256*256)%256)
	local tempc = math.floor(session_id/256%256)
	local tempd = math.floor(session_id%256)
	reqstr = reqstr..string.char(tempa)..string.char(tempb)..string.char(tempc)..string.char(tempd)

	--携带的信息
	reqstr = reqstr..args.msg
	--print("iotmassage send:"..reqstr.." temp:"..tempa..tempb..tempc..tempd)
	--local enstr = reqstr
	local len, enstr = des_encrypt.iot_encode(reqstr)
	--print("iotmassage send:"..enstr)

	write(var.fd,enstr)
end

--服务器给iot的回复
function message.response(kind,session,msg)

	local reqstr  = string.char(math.random(0,255))
	reqstr = reqstr..string.char(math.random(0,255))

	--数据种类
	reqstr = reqstr..string.char(kind)
	--session
	reqstr = reqstr..session
	--携带的信息
	reqstr = reqstr..msg

	--local enstr = reqstr	
	local len, enstr = des_encrypt.iot_encode(reqstr)
	print("iotmassage response:"..enstr)

	write(var.fd,enstr)
end


function message.update(args)

	const = query_sharedata "const"	
	
	var.fd = args.fd
		
	proxy.subscribe(var.fd) 

	var.last_t = os.time()
	var.agent_last_t = os.time()

	while true do

		local ok, msg = pcall(read, var.fd )

		--每个卡位的心跳检测
		if os.time()>var.agent_last_t+const.basket_timeout.iot_heartbeat_t then					
			for obj, handler in pairs(var.object) do					
				local f = handler["checkhearbeat"]	
				if f ~= nil then
					local ok, ret_msg = pcall(f, obj,{msg = nil})
					if ok == false then
						print(string.format("check everyone error"))
					elseif ret_msg==true then
						logger.info("iotmessage checkhearbeat all pos has closed")
						break
					end
				end	
			end
			
			var.agent_last_t = os.time()
		end

		--整个机台的心跳检测
		if os.time()>var.last_t+const.basket_timeout.fd_out_t then
			logger.info("message.update: heartbetat time out")
			break
		end

		if ok and #msg>7 then	
			var.last_t = os.time()		
			--local destr = msg
			local len, destr = des_encrypt.iot_decode(msg)
			
			local kind = string.byte(destr,3,3)

			local temparr = string.sub(destr,4,7)
			local session_id = string.byte(temparr,1)*256*256*256+string.byte(temparr,2)*256*256+string.byte(temparr,3)*256+string.byte(temparr,4)
			local submsg = string.sub(destr,8,-1)

			logger.info("iotmessage dispatch receive,fd:%s,kind:%s,session_id:%d",var.fd,kind,session_id)

			--print_t(var.object)
			if tonumber(kind)==110 then	--注册成功反馈，同一个fd有人登录，消息都调到这里来处理
				logger.info("iot return info：register ok")
				for obj, handler in pairs(var.object) do					
					local f = handler["getregisterres"]	
					if f ~= nil then
						local ok, ret_msg = pcall(f, obj,{fd = var.fd,session_str = string.sub(destr,4,7),msg = submsg})
						if ok == false then
							print(string.format("check everyone  error"))
						elseif ret_msg==true then
							logger.info("iotmessage getregisterres ok ")
						end
					end	
				end
			elseif tonumber(kind)==112 then --iot发送登录请求，同一个fd有人登录，消息都调到这里来处理
				for obj, handler in pairs(var.object) do					
					local f = handler["iotlogin"]	
					if f ~= nil then
						local ok, ret_msg = pcall(f, obj,{fd = var.fd,session_str = string.sub(destr,4,7),msg = submsg})
						if ok == false then
							print(string.format("check everyone  error"))
						elseif ret_msg==true then
							break
						end
					end	
				end
			elseif tonumber(kind) == 113 then
				for obj, handler in pairs(var.object) do				
					local f = handler["heartbeat"]
					if f then
						local ok, err_msg = pcall(f, obj,{kind = kind,session_id = session_id, msg = submsg })
						if not ok then
							print("call server heartbeat  error")
						end
					end	
				end
			elseif tonumber(kind) == 121 then
				for obj, handler in pairs(var.object) do					
					local f = handler["setoutcheck"]
					
					if f then
						local ok, err_msg = pcall(f, obj,{kind = kind,session_id = session_id, msg = submsg })
						if not ok then
							print(string.format("call server setoutcheck  error"))
						end
					end	
				end
			elseif tonumber(kind) == 122 then
				for obj, handler in pairs(var.object) do				
					local f = handler["outcoin"]
			
					if f then
						local ok, err_msg = pcall(f, obj, {kind = kind,session_id = session_id,msg = submsg })
						if not ok then
							print(string.format("call server outcoin  error"))
						end
					end	
				end
			elseif tonumber(kind)==130 then
				for obj, handler in pairs(var.object) do					
					local f = handler["getmachstate"]
					
					if f then
						local ok, err_msg = pcall(f, obj,{kind = kind,session_id = session_id, msg = submsg })
						if not ok then
							logger.info("call server getmachstate  error")
						end
					end	
				end
			elseif tonumber(kind) == 140 then
				for obj, handler in pairs(var.object) do				
					local f = handler["reportscore"]
			
					if f then
						local ok, err_msg = pcall(f, obj, {kind = kind,msg = submsg })
						if not ok then
							print(string.format("call server reportscore  error"))
						end
					end	
				end
			else 
				local session = var.session[session_id]		
				var.session[session_id] = nil

				if session~=nil then
					logger.info("    session_id:%d,sessionname:%s",session_id,session.name)

					for obj, handler in pairs(var.object) do
						local f = handler[session.name]
						if f then
							local ok, err_msg = pcall(f, obj, {kind = kind,even_name = session.name,msg = submsg })
							if not ok then
								print(string.format("session %s[%d] for [%s] error : %s", session.name, session_id, tostring(obj), err_msg))
							end
						end
					end
				end
			end
		end
	end
		
end

return message
