local skynet = require "skynet"
local socket = require "socket"
local proxy = require "socket_proxy"
local packer = require "packer"
local print_t = require "print_t"
local logger = require "logger"

local service = require "service"
local query_sharedata = require "query_sharedata"

require "skynet.manager"

local wechathandler = {}

--微信登录后，openid对应的机台位置
local online_openid_machpos = {}

local const  

--to iot,登录
function wechathandler.WechatLogIn(args)

	local client_info={}
	local retdata = {}
	
	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)
	local mach = client_info.game..client_info.machid

	if online_openid_machpos[client_info.openid] ~= nil then
		logger.info("you has logined other machine")
		retdata.errcode = "101"
		retdata.errmsg = "WechatLogin you has logined other machine"
		return retdata
	else
		local iotmanager = skynet.uniqueservice("iotmanager") 

		--游戏设备如果分配了agent，说明游戏设备与服务器已经连接好
		local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)
		local ret = nil
		if agent == nil then
			logger.info("mach don‘t login")

			retdata.errcode = "102"
			retdata.errmsg = "WechatLogin mach do not login"
			return retdata
		else
			if client_info.game=="106" then

				local pos_n = skynet.call(agent,"lua","getpos",mach) 
				
				if pos_n ~= nil then  
					client_info.pos = pos_n --具体对应卡位
					--print("client_info.pos:"..mach.." "..client_info.pos)
				end
				
				--机台上对应openid
				local iotopenid = skynet.call(agent,"lua","getopenid",client_info.pos)
				
				--有人登录
				if iotopenid ~= nil then
					logger.info("someone has logined this machine")
					retdata.errcode = "105"
					retdata.errmsg = "WechatLogin someone has logined this machine"
					return retdata
				else			
					local onegamecoin = skynet.call(agent,"lua","getonegamecoin",client_info.pos)
					--mach登录后，数据还没有发给服务器
					if onegamecoin == nil then
						retdata.errcode = "104"
						retdata.errmsg = "WechatLogin get iot data error"
						return retdata
					else
						--锁定游戏
						client_info.g_state = const.game_state.login

						client_info.qrscene = args.qrscene--client_info.wx_pos..string.sub(mach,1,3).."1234"..string.sub(mach,4,10) 
						client_info.countdown = const.basket_state_t.login_t
						
						local act_name = "changegamestate"
						skynet.call(agent,"lua",act_name,client_info)
						ret = skynet.call(agent,"lua","getevenmsg",client_info.pos,act_name,const.basket_timeout.iot_out_t)

						if ret == false or ret == nil then
							logger.info("WechatLogin %s iot time out",act_name)
				
							retdata.errcode = "103"
							retdata.errmsg = "WechatLogin iot time out"
							return retdata
						else
							--设置相应openid有机台登录了
							online_openid_machpos[client_info.openid] = mach	
							--给设备分配openid,初始化其他信息
							skynet.call(agent,"lua","setopenid",client_info.pos,client_info.openid) 
							logger.info("wechat user %s login in %s",client_info.openid,online_openid_machpos[client_info.openid])

							--logger.info("WechatLogin %s ok",act_name)
							skynet.call(agent,"lua","setevenmsg",client_info.pos,act_name,nil)

							retdata.errcode = "0"
							retdata.errmsg = "WechatLogin ok"
							retdata.onegamecoin = tostring(onegamecoin)

							local last_t = skynet.call(agent,"lua","getstatt",client_info.pos)
							retdata.countdown = tostring(const.basket_state_t.login_t- (os.time() - last_t))
							return retdata
						end
					end
				end
			end
		end		
	end
end

--登出
function wechathandler.WechatLogOut(args)
	
	local client_info={}
	local retdata = {}
	
	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)

	local mach = client_info.game..client_info.machid
	
	if online_openid_machpos[client_info.openid] ~= nil then
				
		logger.info("wechat user %s logout from %s",client_info.openid,mach..client_info.pos)
		
		local iotmanager = skynet.uniqueservice("iotmanager") 

		--游戏设备如果分配了agent，说明游戏设备与服务器已经连接好
		local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)
		
		if  agent == nil then
			logger.info("mach do not login")

			retdata.errcode = "112"
			retdata.errmsg = "WechatLogOut mach do not login"
			return retdata
		else
			if client_info.game=="106" then
				local pos_n = skynet.call(agent,"lua","getpos",mach) 
				if pos_n ~= nil then  
					client_info.pos = pos_n --具体对应卡位
				end
			end
			
			--logger.info("wechat user %s logined in :%s",client_info.openid,online_openid_machpos[client_info.openid])
			online_openid_machpos[client_info.openid] = nil
			--清空iot的openid
			skynet.call(agent,"lua","setopenid",client_info.pos,nil)

			--锁定游戏
			client_info.g_state = const.game_state.logout
			client_info.qrscene = args.qrscene  

			local act_name = "changegamestate"
			skynet.call(agent,"lua",act_name,client_info)
			
			local ret = skynet.call(agent,"lua","getevenmsg",client_info.pos,act_name,const.basket_timeout.iot_out_t)
			
			if ret == false then
				logger.info("WechatLogOut %s iot time out",act_name)
	
				retdata.errcode = "113"
				retdata.errmsg = "WechatLogOut iot time out"
				return retdata
			else
				logger.info("WechatLogOut %s ok",act_name)
				skynet.call(agent,"lua","setevenmsg",client_info.pos,act_name,nil)
			
				retdata.errcode = "0"
				retdata.errmsg = "WechatLogOut ok"
				return retdata
			end

		end
	else
		logger.info("user do not login")
		retdata.errcode = "111"
		retdata.errmsg = "WechatLogout user has not logined"
	end	
	return retdata
end

--to iot,投币
function wechathandler.WechatCoinIn(args)
	
	local client_info={}
	local retdata = {}

	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)
	client_info.remain_coin = tonumber(args.remain_coin)
	
	local mach = client_info.game..client_info.machid
	
	if online_openid_machpos[client_info.openid] ~= nil then

		local iotmanager = skynet.uniqueservice("iotmanager") 
		local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)

		if agent == nil then
			logger.info("mach do not login")
			retdata.errcode = "122"
			retdata.errmsg = "WechatPay mach do not login"
		else
			if client_info.game=="106" then
				local pos_n = skynet.call(agent,"lua","getpos",mach) 
				if pos_n ~= nil then  
					client_info.pos = pos_n --具体对应卡位
				end
			end

			local ret = skynet.call(agent,"lua","paytoiot",client_info)
			
			--投币成功，才有后续处理
			if ret.errcode == "0" then	--可进入游戏
				--锁定游戏
				client_info.g_state = const.game_state.select_mode
				client_info.qrscene = args.qrscene -- client_info.wx_pos..string.sub(mach,1,3).."1234"..string.sub(mach,4,10) 
				client_info.countdown = const.basket_state_t.matching_t

				local act_name = "changegamestate"
				skynet.call(agent,"lua",act_name,client_info)
				
				local msgret = skynet.call(agent,"lua","getevenmsg",client_info.pos,act_name,const.basket_timeout.iot_out_t)
				if msgret ~= nil then
					retdata = ret
					retdata.matching_t = tostring(const.basket_state_t.matching_t)
					logger.info("WechatPay iot has enough coins")
					return retdata
				end
			elseif ret.errcode == "1" then   --需要向iot投币，等流程继续处理 
				ret = skynet.call(agent,"lua","getevenmsg",client_info.pos,"pay",const.basket_timeout.iot_out_t)
					
				if ret == false then
					retdata.errcode = "123"
					retdata.errmsg = "iot time out"
					logger.info("WechatPay %s time out","pay")
				else
					if ret.errcode == "0" then
						logger.info("WechatPay pay to iot ok,coin:%s",ret.coin)
					else
						logger.info("WechatPay pay to iot error")
					end
 					
					skynet.call(agent,"lua","setevenmsg",client_info.pos,"pay",nil)
					retdata = ret
					retdata.matching_t = tostring(const.basket_state_t.matching_t)
				end
				return retdata			
			else  --游戏币数不够
				retdata = ret
				return retdata	
			end

		end
	else
		logger.info("user do not login")
		retdata.errcode = "121"
		retdata.errmsg = "WechatPay user do not login"
	end 
	return retdata
end

--选择游戏模式
function wechathandler.WechatChooseMode(args)
	local client_info={}
	local retdata = {}
	
	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)
	client_info.mode = tonumber(args.mode_kind)

	local mach = client_info.game..client_info.machid

	local iotmanager = skynet.uniqueservice("iotmanager") 
	local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)
	
	if agent == nil then
		logger.info("mach do not login")
		retdata.errcode = "132"
		retdata.errmsg = "WechatMatching mach do not login"

		return retdata
	else
		if client_info.game=="106" then
			local pos_n = skynet.call(agent,"lua","getpos",mach) 
			if pos_n ~= nil then  
				client_info.pos = pos_n --具体对应卡位
			end
		end

		if client_info.mode > const.game_mode.net_single then
			--查询是否已经进入房间
			local room_id = skynet.call(agent,"lua","getroomid",client_info.pos)
			if room_id ~= nil then
				retdata.errcode = "134"
				retdata.errmsg = "WechatChooseMode "..client_info.openid.." has join room"
				retdata.room_id = tostring(room_id)
			end

			local last_t = skynet.call(agent,"lua","getstatt",client_info.pos)
			client_info.countdown = const.basket_state_t.matching_t-(os.time()-last_t)
			
			if client_info.countdown<1 then
				client_info.countdown = 1
			end

			--选择成功后，进入房间匹配状态
			client_info.g_state = const.game_state.matching

			local act_name = "changegamestate"

			skynet.call(agent,"lua",act_name,client_info)
			
			local ret = skynet.call(agent,"lua","getevenmsg",client_info.pos,act_name,const.basket_timeout.iot_out_t)
						
			if ret == false then
				retdata.errcode = "133"
				retdata.errmsg = "iot time out"
				logger.info("WechatChooseMode %s time out",act_name)
			else
				retdata.errcode = "0"
				retdata.mode = tostring(client_info.mode)
				retdata.errmsg = "WechatChooseMode net game:"..client_info.mode
				logger.info("WechatChooseMode %s ok",act_name)
			end
		else
			logger.info("select_mode, single game openid:%s,pos:%s",client_info.openid,client_info.pos)
			retdata = skynet.call(agent,"lua","startgame",client_info.pos,const.game_mode.net_single)
		end
	end
	return retdata
end

--房间匹配
function wechathandler.WechatMatching(args)
	local client_info={}
	local retdata = {}
	
	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)
	local mach = client_info.game..client_info.machid

	local iotmanager = skynet.uniqueservice("iotmanager") 
	local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)
	local room_id = nil

	if agent == nil then
		logger.info("mach do not login")
		retdata.errcode = "142"
		retdata.errmsg = "WechatMatching mach do not login"

		return retdata
	else
		if client_info.game=="106" then
			local pos_n = skynet.call(agent,"lua","getpos",mach) 
			if pos_n ~= nil then  
				client_info.pos = pos_n --具体对应卡位
			end
		end

		local mode  = skynet.call(agent,"lua","getgamemode",client_info.pos)
		client_info.mode = mode
		
		--只处理联网模式
		if mode~=nil and mode > const.game_mode.net_single then
					
			room_id = skynet.call(agent,"lua","getroomid",client_info.pos)

			if room_id ~= nil then
				retdata.errcode = "141"
				retdata.errmsg = "WechatMatching "..client_info.openid.." has join room"
				retdata.room_id = tostring(room_id)
				retdata.mode = client_info.mode
			else
				local ret = nil
				local last_t = skynet.call(agent,"lua","getstatt",client_info.pos)
				local team = nil
				local remain_t = const.basket_state_t.matching_t-(os.time()-last_t)
				
				if remain_t<const.basket_state_t.createroom_t then
					remain_t = const.basket_state_t.createroom_t
				end

				ret,room_id,mode,team,remain_t = skynet.call(".room_mgr", "lua", "join_room",client_info,remain_t)
				
				if ret == nil then
					retdata.errcode = "146"
					retdata.errmsg = "WechatMatching join room no enough player"
				elseif room_id~=nil then
					client_info.g_state = const.game_state.matchok
					client_info.countdown = remain_t
										
					--匹配成功后，向iot发送匹配成功，进入房间匹配状态
					local act_name = "changegamestate"
					skynet.call(agent,"lua",act_name,client_info)
					
					ret = skynet.call(agent,"lua","getevenmsg",client_info.pos,act_name,const.basket_timeout.iot_out_t)
			
					if ret == false then
						retdata.errcode = "144"
						retdata.errmsg = "iot time out"
						logger.info("WechatMatching %s time out",act_name)
					else
						skynet.call(agent,"lua","setroomid",client_info.pos,room_id)
						
						retdata.errcode = "0"
						retdata.errmsg = "WechatMatching join room"
						retdata.room_id = tostring(room_id)
						retdata.mode = tostring(mode)
						retdata.team_id = tostring(team)
						retdata.remaining_t = tostring(remain_t)
						logger.info("WechatMatching join room:%s remain time:%s",room_id,remain_t)
					end
				else
					retdata.errcode = "143"
					retdata.errmsg = "WechatMatching join room error"
				end
			end
		else
			retdata.errcode = "145"
			retdata.errmsg = "WechatMatching mode is error"
		end
	end
	
	return retdata
end

--游戏中
function wechathandler.WechatPlaying(args)
	local client_info={}
	local retdata = {}
	
	client_info.openid = args.openid
	client_info.pos = string.sub(args.qrscene,1,2)
	client_info.game = string.sub(args.qrscene,3,5)
	client_info.machid = string.sub(args.qrscene,10,15)
	local mach = client_info.game..client_info.machid

	--只处理联网模式
	local iotmanager = skynet.uniqueservice("iotmanager") 
	local agent = skynet.call(iotmanager,"lua","getagent",mach,client_info.pos)
	
	if agent == nil then
		logger.info("mach do not login")
		retdata.errcode = "152"
		retdata.errmsg = "WechatMatching mach do not login"
	else
		if client_info.game=="106" then
			local pos_n = skynet.call(agent,"lua","getpos",mach) 
			if pos_n ~= nil then  
				client_info.pos = pos_n --具体对应卡位
			end
		end

		local mode  = skynet.call(agent,"lua","getgamemode",client_info.pos)

		--只处理联网模式
		if mode ~= nil and mode > const.game_mode.net_single then
			retdata = skynet.call(agent,"lua","getscore")
			retdata.errcode = "0"
			retdata.errmsg = "WechatPlaying get score and rank"
		else
			retdata.errcode = "151"
			retdata.errmsg = "WechatPlaying get model error"
		end
	end
	
	return retdata
end

function wechathandler.clearopenid(openid)
	online_openid_machpos[openid] = nil
end

skynet.start(function()

	logger.info("wechathandler starting...")
	const = query_sharedata "const"
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = wechathandler[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command11 %s", tostring(cmd)))
		end
	end)
	
end)
