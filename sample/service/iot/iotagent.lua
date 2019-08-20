require "skynet.manager"
local skynet = require "skynet"
local service = require "service"
local logger = require "logger"
local proxy = require "socket_proxy"

local query_sharedata = require "query_sharedata"
local cache_util = require "cache_util"
local sqlutil = require "sqlutil"

local message = require "iotmessage"
local print_t = require "print_t"

--常量
local iotagent = {}
local const = {}  
local data = {}
--一个agent中，卡位对应的信息
-- 	game 		--游戏代号
-- 	machid 		--机台编号
--	mach		--game..machid
-- 	pos 		--位置
-- 	openid 		--openid
-- 	g_state 		--游戏状态
--  state_t			--状态维持的时间
-- 	onegamecoin 	--一次游戏需要的币数
-- 	wx_coin 		--微信拥有的币数
-- 	iotcoinnum 		--iot已有的投币数量
-- 	cash 			--本次投给iot的币数
-- 	game_mode 		--游戏模式，0：本地连线，1：单机，2：单人，3：团队
-- 	room_id 		--设备锁处的房间
--  mach_state		--机器的状态
--  mach_err		--机器的错误码提示
-- 	score			--分数
-- 	rank 			--排名
--  fd				--对应的fd。
local pos_info = {}
local agent_even_msg = {} 

local even = {}
message.bind({}, even)

function iotagent.setopenid(pos,openid)
	
	local pos_n = tonumber(pos)

	if pos_info ~= nil and pos_info[pos_n] ~= nil then

		pos_info[pos_n].openid = openid
		return openid
 	end

	return nil
end

function iotagent.getopenid(pos)
	local pos_n = tonumber(pos)
	if pos_info ~= nil and pos_info[pos_n] ~= nil and pos_info[pos_n].openid~= nil then

		return pos_info[pos_n].openid
 	end

	return nil
end

--通过机器序列号，反查连接到android时，fd分配给本设备的pos
function iotagent.getpos(mach)
	for k,v in pairs(pos_info) do
		--print_t(v)
		if v.mach == mach then
			return k
		end
	end
	return nil
end

function iotagent.getonegamecoin(pos)
	local pos_n = tonumber(pos)
	
	if pos_info[pos_n]~=nil and pos_info[pos_n].onegamecoin~=nil then
		return pos_info[pos_n].onegamecoin
	end
	return nil
end

function iotagent.setroomid(pos,room_id)
	
	local pos_n = tonumber(pos)
	--print("in iotagent.setroomid,pos"..pos_n)
	--print_t(pos_info[pos_n])
	if pos_info ~= nil and pos_info[pos_n] ~= nil then
		pos_info[pos_n].room_id = room_id	
 	end
end

function iotagent.getroomid(pos)

	local pos_n = tonumber(pos)

	if pos_info ~= nil and pos_info[pos_n] ~= nil then
		return pos_info[pos_n].room_id
 	end
end

function iotagent.getgamemode(pos)
	local pos_n = tonumber(pos)
	
	if pos_info ~= nil and pos_info[pos_n] ~= nil then
		return pos_info[pos_n].game_mode
 	end
	 return nil
end

--获取状态切换后的时间
function iotagent.getstatt(pos)
	local pos_n = tonumber(pos)
	
	if pos_info ~= nil and pos_info[pos_n] ~= nil then
		return pos_info[pos_n].state_t
 	end
	 return nil
end

--游戏过程中每隔一段时间获取游戏分数机排名，如果游戏结束了，返回游戏结束
function iotagent.getscore(pos)
	
	local pos_n = tonumber(pos)

	if pos_info ~= nil and pos_info[pos_n] ~= nil then
		if pos_info[pos_n].g_state == const.game_state.play or pos_info[pos_n].g_state == const.game_state.over then
			return {state = pos_info[pos_n].g_state,score= pos_info[pos_n].score,rank = pos_info[pos_n].rank}
		end
	end
	return nil
end

function iotagent.startgame(pos,mode)

	local retdata = {}
	local pos_n = tonumber(pos)

	local client_info = {}
	client_info.openid = pos_info[pos_n].openid
	client_info.game = pos_info[pos_n].game
	client_info.machid = pos_info[pos_n].machid
	client_info.pos = pos_info[pos_n].pos
	client_info.g_state = const.game_state.play
	
	if mode == const.game_mode.net_single then
		client_info.countdown = 15
		client_info.mode = mode
		iotagent.setroomid(pos_n,nil)
	else
		client_info.countdown = 0
		client_info.mode = pos_info[pos_n].game_mode
	end		
	iotagent.changegamestate(client_info)

	local ret = iotagent.getevenmsg(pos_n,"changegamestate",const.basket_timeout.iot_out_t)

	if ret == false then
		retdata.errcode = "152"
		retdata.errmsg = "iot time out"
		logger.info("in startgame %s changegamestate to play time out",client_info.openid)
	else
		retdata.errcode = "0"
		retdata.errmsg = client_info.openid.." start game"
		logger.info("in startgame %s changegamestate to play ok",client_info.openid)
	end

	iotagent.setevenmsg(pos_n,"changegamestate",nil)
	return retdata
end

--结束游戏
function iotagent.stopgame(args)
	
	local pos_n = tonumber(args.pos)

	if pos_info[pos_n].game_mode > const.game_mode.net_single then
		--获取排名信息
		local result_info = skynet.call(".room_mgr", "lua", "getfinalresult",pos_info[pos_n].room_id)
		
		local selfrank,highestscore = skynet.call(".room_mgr", "lua", "update_score",pos_info[pos_n].room_id,pos_info[pos_n].openid,pos_info[pos_n].score)

		local race_info = {}
		
		--把排名发给设备
		for k,v in pairs(result_info) do
			if tonumber(v.pos) == pos_n then
				iotagent.setrank(pos_n,highestscore,v.rank)

				local temp = {}
				temp.openid = v.openid
				temp.point = tostring(v.point)
				race_info[k] = temp
				break
			end
		end
			
		--把游戏数据发给微信端
		skynet.call(service.wechathttpc,"lua","gameover",pos_info[pos_n].room_id,args.countdown,race_info)
		-- print("iotagent.setroomid pos :"..pos_n)
		iotagent.setroomid(pos_n,nil)
	end
	
	--非本地，要向设备发关闭信号
	if pos_info[pos_n].game_mode > const.game_mode.local_play then
		local client_info = {}
		client_info.openid = pos_info[pos_n].openid
		client_info.game = pos_info[pos_n].game
		client_info.machid = pos_info[pos_n].machid
		client_info.pos = pos_info[pos_n].pos
		client_info.g_state = args.g_state
		
		iotagent.changegamestate(client_info)

		local ret = iotagent.getevenmsg(pos_n,"changegamestate",const.basket_timeout.iot_out_t)

		if ret == false then
			logger.info("in stopgame %s changegamestate to stop time out",client_info.openid)
		else
			logger.info("in stopgame %s changegamestate to stop ok",client_info.openid)
		end
		
		iotagent.setevenmsg(pos_n,"changegamestate",nil)
		
		if pos_info[pos_n].game_mode == const.game_mode.net_single then
			iotagent.setroomid(pos_n,nil)
		end
	end

	return true
end

--设置某个动作的状态
function iotagent.setevenmsg(pos,even_name,msg)
	local pos_n = tonumber(pos)
	if even_name ~= nil then
		--logger.info("set even_msg pos_n:%d,even:%s,msg:%s",pos_n,even_name,msg)
		
		if agent_even_msg == nil or agent_even_msg[pos_n] == nil then
			local info = {}
			info[even_name] = msg
			agent_even_msg[pos_n] = info
		else
			agent_even_msg[pos_n][even_name] = msg
		end
	end
end

--获取某个动作的状态，out_t:超时设置
--模拟非阻塞异步实现
function iotagent.getevenmsg(pos,cmd,out_t)
	local temp_t = os.time()
	local pos_n = tonumber(pos)

	--logger.info("get even_msg:pos:%d,cmd:%s,limit time:%d",pos_n,cmd,out_t)

	while true do
		if os.time() - temp_t > out_t then
			return false
		elseif agent_even_msg~=nil and agent_even_msg[pos_n]~=nil and agent_even_msg[pos_n][cmd]~=nil then
			return agent_even_msg[pos_n][cmd]
		end
		skynet.sleep(100)
	end
end

--初始化机器序列号，全部归零
function iotagent.resetsn(args)
	print("begin reset mach sn")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--1为类型
	message.send("resetsn",{kind = 1,msg = reqstr})
end

--锁上指定机器序列号的机器
function iotagent.lock(args)
	logger.info("begin lock")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)
	reqstr = reqstr..string.char(args.lock)

	--2为类型
	message.send("lock",{kind = 2,msg = reqstr})
end

--设置设备设定参数
function iotagent.setmachsetting(args)
	logger.info("begin setmachsetting")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)
	reqstr = reqstr..args.settingdata

	--15为类型
	message.send("setmachsetting",{kind = 15,msg = reqstr})
end

--获取设备设定参数
function iotagent.getmachsetting(args)
	logger.info("begin getmachsetting")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--16为类型
	message.send("lock",{kind = 16,msg = reqstr})
end

--清零设备查账数据
function iotagent.clearmachdata(args)
	logger.info("begin clearmachdata")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)
	
	--17为类型
	message.send("clearmachdata",{kind = 17,msg = reqstr})
end

--获取设备查账数据
function iotagent.getmachdata(args)
	logger.info("begin getmachdata")
	
	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--18为类型
	message.send("getmachdata",{kind = 18,msg = reqstr})

	return nil
end

--支付：需要先获取支付验证码，再发起支付
function iotagent.paytoiot(args)

	logger.info("begin paytoiot:%s(%s)",args.machid,args.pos)

	local pos_n = tonumber(args.pos)
	local retdata = {}

	pos_info[pos_n].wx_coin = args.remain_coin

	logger.info("iotagent.paytoiot,onegamecoin:%s,iotcoinnum:%s wx_coin:%s",pos_info[pos_n].onegamecoin,pos_info[pos_n].iotcoinnum,pos_info[pos_n].wx_coin)
	if pos_info[pos_n].iotcoinnum >= pos_info[pos_n].onegamecoin then
		pos_info[pos_n].cash = 0
		pos_info[pos_n].g_state = args.g_state
		retdata = {errcode = "0",errmsg ="coin to iot ok",coin = "0"} 
	elseif pos_info[pos_n].iotcoinnum + pos_info[pos_n].wx_coin >= pos_info[pos_n].onegamecoin then
		--支付卡位,需要传给iot
		local reqstr = string.char(pos_n)

		pos_info[pos_n].cash = pos_info[pos_n].onegamecoin - pos_info[pos_n].iotcoinnum			
		logger.info("%s pay cash:%s",pos_info[pos_n].openid,pos_info[pos_n].cash)
		
		--19为类型
		message.send("getpaycode",{kind = 19,msg = reqstr})

		retdata = {errcode = "1",errmsg ="now wx pay to iot",coin = tostring(pos_info[pos_n].cash)} 
	else
		pos_info[pos_n].cash = 0
		local needcoin = pos_info[pos_n].onegamecoin - (pos_info[pos_n].iotcoinnum + pos_info[pos_n].wx_coin)
		retdata = {errcode = "124",errmsg ="need more coin",coin = tostring(needcoin)} 
	end

	return  retdata
end

--设置游戏设定参数
function iotagent.setgamesetting(args)
	logger.info("begin setgamesetting")

	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)
	reqstr = reqstr..args.setting
	
	--23为类型
	message.send("setgamesetting",{kind = 23,msg = reqstr})
end

--获取游戏设定参数
function iotagent.getgamesetting(args)
	logger.info("begin getgamesetting at pos:%s",args.pos)
	
	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--24为类型
	message.send("getgamesetting",{kind = 24,msg = reqstr})
end

--清除游戏数据
function iotagent.cleargamedata(args)
	logger.info("begin cleargamedata")
	
	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--25为类型
	message.send("cleargamedata",{kind = 25,msg = reqstr})
end

--获取游戏数据
function iotagent.getgamedata(args)
	logger.info("begin getgamedata")
	
	local pos_n = tonumber(args.pos)
	local reqstr = string.char(pos_n)

	--26为类型
	message.send("getgamedata",{kind = 26,msg = reqstr})
end

--玩家切换游戏状态
function iotagent.changegamestate(args)

	logger.info("begin changegamestate:%s(%s),state:%s",args.machid,args.pos,args.g_state)

	local pos_n = tonumber(args.pos)
	
	pos_info[pos_n].g_state = args.g_state
	--切换状态的起始时间
	pos_info[pos_n].state_t = os.time()

	local reqstr = string.char(pos_n)
	if args.g_state~=nil then
		pos_info[pos_n].g_state = args.g_state
		
		--发送数据
		reqstr = reqstr..string.char(tonumber(args.g_state))

		if args.countdown~=nil and args.countdown>0 then
			reqstr = reqstr..string.char(tonumber(args.countdown))
		else 
			reqstr = reqstr..string.char(0)
		end
		
		--print("countdown:"..args.countdown)
		if args.mode~=nil then
			pos_info[pos_n].game_mode = args.mode	
			reqstr = reqstr..string.char(tonumber(pos_info[pos_n].game_mode))
		else 
			reqstr = reqstr..string.char(0)
		end
	end

	--31为类型
	message.send("changegamestate",{kind = 31,msg = reqstr})
	
	logger.info("changegamestate send data ok")	
end

--写入游戏排名及最高分
function iotagent.setrank(pos,score,rank)
	logger.info("begin setrank")
	
	local pos_n = tonumber(pos)
	local score_c = string.char(math.floor(score/256))..string.char(math.floor(score%256))
	local rank = string.char(rank)
	local reqstr = string.char(pos_n)..score_c..rank

	--41为类型
	message.send("setrank",{kind = 41,msg = reqstr})
end

--fd上有人登录后，其他卡位再有人登录
function even:iotlogin(args)
	
	local mach,pos = skynet.call(service.iotmanager, "lua", "iotlogin",args)

	if mach ~= nil and pos~=nil then
 		local ret = skynet.call(service.iotmanager, "lua", "assign", args.fd,mach,pos)
		if ret then
			logger.info("in even iotlogin ok,fd:%d mach:%s(%s)",args.fd,mach,pos)
			return	true
		else
			logger.info("Assign failed fd:%s to %s(%s)", args.fd, mach,pos)
		end
	end
	return false
end

--fd上有人登录后，其他卡位的注册处理
function even:getregisterres(args)

	local pos = (math.floor(string.byte(args.msg,1,1)/10))..(math.floor(string.byte(args.msg,1,1)%10))
	local res = string.byte(args.msg,2,2)
	
	if res == 1 then
		logger.info("iot register return even：ok")
		return true
	else
		logger.info("iot register return even：error")
		return false
	end
end

function even:resetsn(args)
	logger.info("resetsn ok")
end

--指定卡位心跳
function even:heartbeat(args)
	local pos_n = string.byte(args.msg,1,1)

	if pos_n==nil or pos_info[pos_n]==nil then
		return false
	end

	pos_info[pos_n].last_t = os.time()
	
	--第一次心跳时，游戏设置没有设置(onegamecoin为nil)，向设备请求游戏设定数据
	if pos_info[pos_n].onegamecoin == nil then
		local args = {}
		args.pos = pos_n
		iotagent.getgamesetting(args)
	end
	
	--向客户端发回心跳
	local reqstr = string.char(pos_n)
	--13为类型
	message.send("hearbeat",{kind = 13,session_id = args.session_id,msg = reqstr})

	--logger.info("heartbeat ok %d,%d",pos_n,pos_info[pos_n].last_t )

	return true
end

--设置机器参数反馈
function even:setmachseting(args)
	if string.byte(args.msg,2,2) == 1 then
		logger.info("setmachseting ok")
	else
		logger.err("setmachseting error")	
	end
end

--获取机器参数反馈
function even:getmachsetting(args)

	local pos_n = string.byte(args.msg,1,1)
	local setting = string.byte(args.msg,2,6)
	
	if setting~=nil then
		iotagent.setevenmsg(pos_n,args.even_name,setting)
	else
		logger.err("getmachsetting error")	
	end
end

--机器查账数据清零反馈
function even:clearmachdata(args)
	
	local pos_n = string.byte(args.msg,1,1)

	--是否成功标志
	local res = string.byte(args.msg,2,2)

	if res ==1 then
		--logger.info("clearmachdata ok")

		iotagent.setevenmsg(pos_n,args.even_name,true)
	else
		logger.err("clearmachdata error")	
	end
end

function even:getmachdata(args)
	local pos_n = string.byte(args.msg,1,1)
	
	local machdata = string.byte(args.msg,2,29)

	if machdata~= nil then
		--logger.info("getmachdata ok")
		iotagent.setevenmsg(pos_n,args.even_name,machdata)
	end
end

--判断回传的信息是否为支付验证码
function even:getpaycode(args)

	local pos_n = string.byte(args.msg,1,1)
	--是否成功标志
	local res = string.byte(args.msg,2,2)
	logger.info("in getpaycode res:"..res)

	if res == 1 then
		--支付卡位,校验码
		local str = string.char(pos_n)..string.sub(args.msg,3,6)
		
		logger.info("in getpaycode cash:"..pos_info[pos_n].cash)	

		--支付值
		str = str..string.char(math.floor(pos_info[pos_n].cash/256))..string.char(math.floor(pos_info[pos_n].cash%256) )
		message.send("pay",{kind = 20,msg = str})
	else
		logger.err("getpaycode res error")	
	end
end

--判断回传的信息是否为支付成功
function even:pay(args)
	local retdata = {}

	local pos_n = string.byte(args.msg,1,1)
	local ret = string.byte(args.msg,2,2)

	if tonumber(ret)==1 then
			
		local sqlarg = {openid = pos_info[pos_n].openid, incharges_id=0, game_id=pos_info[pos_n].game, mach_id=pos_info[pos_n].machid,play_no = pos_n, total_fee = pos_info[pos_n].cash,is_incharged = 1}

		local res = cache_util.call('wx_db', 'insert_player_charge_order', sqlarg)
		
		if not res then
			logger.err("insert_player_charge_order sql err")
			return {errcode = 2,errmsg = 'DB error'}
		end
		
		logger.info("%s pay to mach:%s(%d) cash:%d",pos_info[pos_n].openid,pos_info[pos_n].mach,pos_n,pos_info[pos_n].cash)
		
		pos_info[pos_n].g_state =  const.game_state.select_mode
		retdata = {errcode = "0",errmsg ="coin to iot ok",coin = tostring(pos_info[pos_n].cash)} 
		iotagent.setevenmsg(pos_n,args.even_name,retdata)
	else 
		logger.err("pay to iot error")
		retdata = {errcode = "125",errmsg ="coin in error"} 
		iotagent.setevenmsg(pos_n,args.even_name,retdata)
	end
end

function even:setoutcheck(args)
	
	local pos_n = string.byte(args.msg,1,1)
	local outkind = string.byte(args.msg,2,2)

	--生成新的校验信息给iot设备
	local reqstr = string.char(pos_n)..string.char(1)..string.char(outkind)

	pos_info[pos_n].checkcode = string.char(math.random(0,255))..string.char(math.random(0,255))..string.char(math.random(0,255))..string.char(math.random(0,255))
		
	reqstr = reqstr..pos_info[pos_n].checkcode 
	print("in setoutcheck pos_n and kind:"..pos_n..","..outkind..",checkcode:"..string.byte(pos_info[pos_n].checkcode,1,1)..","..string.byte(pos_info[pos_n].checkcode,2,2))

	message.send("outcoin",{kind = 21,session_id = args.session_id,msg = reqstr})
end

function even:outcoin(args)
	--确认退币
	local check = string.sub(args.msg,3,6)
	local pos_n = string.byte(args.msg,1,1)
	
	print("begin outcoin receive check:"..string.byte(check,1,1).." "..string.byte(check,2,2))

	if check == pos_info[pos_n].checkcode then
	
		local outkind = string.byte(args.msg,2,2)
		local value = string.byte(args.msg,7,7)*256+string.byte(args.msg,8,8)

		--结果发回给iot设备
		local reqstr = string.char(pos_n)..string.char(1)

		--本消息不需要回应。所以outcoinack函数其实不存在
		message.send("outcoinack",{kind = 22,session_id = args.session_id,msg = reqstr})

		logger.info("outcoin send ok")
		iotagent.setevenmsg(pos_n,args.even_name,true)
	end
end

--设置游戏设定参数反馈
function even:setgamesetting(args)

	local pos_n = string.byte(args.msg,1,1)

	--是否成功标志
	local res = string.byte(args.msg,2,2)

	if res ==1 then
		logger.info("setgamesetting ok")
		iotagent.setevenmsg(pos_n,args.even_name,true)
	else
		logger.err("setgamesetting error")	
	end

	return nil
end

--获取游戏设定参数反馈
function even:getgamesetting(args)

	local pos_n = string.byte(args.msg,1,1)
	local setting = string.sub(args.msg,2,-1)
	
	if setting~=nil then
		--logger.info("getgamesetting: %s",setting)
		pos_info[pos_n].onegamecoin = string.byte(setting,1,1)
		
		return true
	end

	return nil
end

--获取游戏数据反馈
function even:getgamedata(args)

	local pos_n = string.byte(args.msg,1,1)
	local gamedata = string.byte(args.msg,2,-1)
	
	if gamedata~=nil then
		logger.info("getgamedata ok")
		--iotagent.setevenmsg(pos_n,args.even_name,setting)
		return true
	end

	return nil
end

--清除游戏数据反馈
function even:cleargamedata(args)

	local pos_n = string.byte(args.msg,1,1)
	--是否成功标志
	local res = string.byte(args.msg,2,2)

	if res == 1 then
		logger.info("cleargamedata ok")
		
		--iotagent.setevenmsg(pos_n,args.even_name,true)
		return true
	else
		logger.err("cleargamedata error")	
	end

	return nil
end

function even:getmachstate(args)
	--判断回传的信息是否成功
	local pos_n = string.byte(args.msg,1,1)

	--机台游戏币数
	pos_info[pos_n].iotcoinnum = string.byte(args.msg,2,2)
	pos_info[pos_n].mach_state = string.byte(args.msg,3,3)
	pos_info[pos_n].mach_err = string.byte(args.msg,4,4)

	local ret = {errcode = "0",iotcointnum = tostring(pos_info[pos_n].iotcoinnum)}
	
	--logger.info("iot pos_info[%d].iotcoinnum:%d,mach_state:%s",pos_n,pos_info[pos_n].iotcoinnum,pos_info[pos_n].mach_state)

	--待机中，表示游戏结束
	if pos_info[pos_n].g_state == const.game_state.play and pos_info[pos_n].mach_state == 2 and pos_info[pos_n].mach_err == 4 then 
		
		--logger.info("in even:getmachstate gamemode:%s",pos_info[pos_n].game_mode)

		if pos_info[pos_n].game_mode > const.game_mode.net_single and iotagent.getroomid(pos_n)~=nil then
			local temp_ret = skynet.call(".room_mgr", "lua", "iotsetuserover",pos_info[pos_n].room_id,pos_info[pos_n].openid,pos_info[pos_n].score)
		else
		
			--单机要马上上传分数
			local client_info = pos_info[pos_n]
			local qrscene = nil		
			if pos_info[pos_n].game == "106" then
				qrscene = "01"
			end
			qrscene = qrscene..pos_info[pos_n].game.."1234"..pos_info[pos_n].machid 

			local score = 1
			if pos_info[pos_n].score ~= nil then
				score = pos_info[pos_n].score
			end

			client_info.countdown = const.basket_state_t.over_t

			logger.info("in even:getmachstate gameover,openid:%s,scorc:%d",pos_info[pos_n].openid,score)

			--单机游戏结束，马上上传分数
			skynet.call(service.wechathttpc,"lua","end_stand_alone",pos_info[pos_n].openid,score,client_info.countdown,qrscene)

			client_info.g_state = const.game_state.over
			iotagent.changegamestate(client_info)
		end
	end

	iotagent.setevenmsg(pos_n,args.even_name,ret)

	return true
end

function even:changegamestate(args)

	local pos_n = string.byte(args.msg,1,1)
	
	--是否成功标志
	local res = string.byte(args.msg,2,2)

	if res == 1 then
		iotagent.setevenmsg(pos_n,args.even_name,res)
		--logger.info("changegamestate ok")
		return true
	else
		logger.err("changegamestate error:%d",res)	
	end

	return nil
end

function even:reportscore(args)

	local pos_n = string.byte(args.msg,1,1)
	local score = string.byte(args.msg,2,2)*256+string.byte(args.msg,3,3)
	
	--卡位没有登录，或者游戏模式为空，返回，不做后续处理。
	if pos_info[pos_n]==nil or pos_info[pos_n].game_mode == nil then
		return
	end

	pos_info[pos_n].score = score
		
	--只有联网才向机器发送当前最高分数和排名
	if pos_info[pos_n].game_mode>const.game_mode.net_single and iotagent.getroomid(pos_n)~=nil then

		local highestscore,selfrank = skynet.call(".room_mgr", "lua", "update_score",pos_info[pos_n].room_id,pos_info[pos_n].openid,score)
		
		--print("in reportscore rank:"..selfrank.." highestscore:"..highestscore)

		if tonumber(highestscore)>0 and tonumber(selfrank)>0 then
			--向机台同步当前最高分数和排名
			iotagent.setrank(pos_n,highestscore,selfrank)
		end
	end
	
	if pos_info[pos_n].game_mode == const.game_mode.net_single then
		local pos_n = string.byte(args.msg,1,1)
		local score = string.byte(args.msg,2,2)*256+string.byte(args.msg,3,3)
		
		--向机台同步当前最高分数和排名
		iotagent.setrank(pos_n,score,1)		
	end

end

function even:setrank(args)
	--判断回传的信息是否成功
	local pos_n = string.byte(args.msg,1,1)
	--是否成功标志
	local res = string.byte(args.msg,2,2)

	if res == 1 then
		iotagent.setevenmsg(pos_n,args.even_name,res)
		return true
	else
		logger.err("setrank error")	
	end

	return nil
end

--清除不在线的卡位,
--返回true：可以清除整个机台信息
local function clear(mach,pos) 

	local pos_n = tonumber(pos)
	local fd = pos_info[pos_n].fd

	local ret = skynet.call(service.iotmanager, "lua", "clearmachpos",fd,mach,pos)

	--如果有玩家登录，相应的openid从服务器退出
	local openid = iotagent.getopenid(pos_n)
	if openid~=nil then

		local qrscene = nil
		if pos_info[pos_n].game == "106" then
			qrscene = "01"
		end	
		qrscene = qrscene..pos_info[pos_n].game.."1234"..pos_info[pos_n].machid 
		
		--退出微信端用户
		skynet.call(service.wechathttpc,"lua","logout",openid,qrscene)
	end

	--卡位对应的机台信息清除	
	if pos_info~=nil and pos_info[pos_n]~=nil then
		pos_info[pos_n] = nil
	end

	if openid == nil then
		logger.info("in iotagent clear pos_n:%d,mach:%s",pos_n,mach)
	else
		logger.info("in iotagent clear pos_n:%d,mach:%s,openid:%s",pos_n,mach,openid)
	end

	--计算还有几个有效卡位
	local count = 0
	for k,v in pairs(pos_info) do
		count = count + 1
	end
	
	--print("iotagent count:"..count)

	if tonumber(count)== 0 then
		--可以关闭proxy
		return true
	end
	
	return false
end

--检测所有机器的心跳，有超时的退出
function even:checkhearbeat()
	for k, inf in pairs(pos_info) do
		if tonumber(os.time())>tonumber(inf.last_t) + (const.basket_timeout.iot_heartbeat_t*5/2) then
			logger.info("in even:checkhearbeat clear,pos_:%s last:%s",k,inf.last_t)
			--是否能关闭proxy
			local ret = clear(inf.mach,inf.pos)
			if ret == true then
				return true
			end
		end
	end
	return false
end

function iotagent.close(fd)
	logger.info("iotagent.close:%s",fd)
	
	for k, inf in pairs(pos_info) do
		clear(inf.mach,inf.pos)
	end

	proxy.close(fd) 
	skynet.exit()	
end

local function new_message(fd)

	proxy.subscribe(fd) 

	pcall(message.update, { fd = fd })

	iotagent.close(fd)
end

function iotagent.add(fd,mach,pos)
	local pos_n = tonumber(pos)

	local inf = {}
	inf.game = string.sub(mach,1,3)
	inf.machid = string.sub(mach,4,9)
	inf.mach = mach
	inf.pos = pos
	inf.last_t = os.time()
	inf.fd = fd

	--logger.info("iotagent.add,mach:%s(%s) pos_n:%d",inf.game..inf.machid,pos,pos_n)

	pos_info[pos_n] = inf
	
	return true
end

--检测每一个卡位的状态，代替原来的定时器处理
local function state_update()
	while true do
		for k, inf in pairs(pos_info) do
			
			local client_info = {}
			local qrscene = nil
			if inf.game == "106" then
				qrscene = "01"
			end
			qrscene = qrscene..inf.game.."1234"..inf.machid 
			local state_last_t = 0
			--本状态持续的时间
			if inf.state_t~=nil and tonumber(inf.state_t)>1000 then
				state_last_t = os.time() - inf.state_t
			end

			if inf.g_state== const.game_state.logout then
			elseif inf.g_state== const.game_state.login then
				if state_last_t > const.basket_state_t.login_t then
			
					client_info.openid = inf.openid
					client_info.game = inf.game
					client_info.machid = inf.machid
					client_info.pos = k
					client_info.g_state = const.game_state.logout
					iotagent.changegamestate(client_info)

					logger.info("login timeout,openid:%s,scene:%s",inf.openid,qrscene,k)	
					--退出微信端用户
					skynet.call(service.wechathttpc,"lua","logout",inf.openid,qrscene)
					--iot的openid清空
					iotagent.setopenid(k,nil)
				end
			elseif inf.g_state== const.game_state.select_mode then
				if state_last_t > const.basket_state_t.matching_t then
					logger.info("select_mode timeout, single game openid:%s",inf.openid)
					iotagent.startgame(k,const.game_mode.net_single)			
				end
			elseif inf.g_state== const.game_state.matching then
				if state_last_t > const.basket_state_t.matching_t then
					logger.info("select_mode timeout, single game openid:%s",inf.openid)
					iotagent.startgame(k,const.game_mode.net_single)			
				end
			elseif inf.g_state== const.game_state.matchok then
			elseif inf.g_state== const.game_state.roomok then
			elseif inf.g_state== const.game_state.play then
				--游戏中不能停止，强制退出
				if state_last_t > 6*60 then
					client_info.openid = inf.openid
					client_info.game = inf.game
					client_info.machid = inf.machid
					client_info.pos = k
					client_info.g_state = const.game_state.logout
					client_info.countdown = const.basket_state_t.login_t
					client_info.mode = inf.game_mode
					iotagent.changegamestate(client_info)

					--logger.info("return1 logout")
					--print("inf.openid:"..inf.openid.."qrscene:"..qrscene)
					
					--退出微信端用户
					skynet.call(service.wechathttpc,"lua","logout",inf.openid,qrscene)
					--iot的openid清空
					iotagent.setopenid(k,nil)
				end
			elseif inf.g_state== const.game_state.over then
				--游戏结束，超时处理
				--print("over state_last_t:"..state_last_t)
				if state_last_t > const.basket_state_t.over_t then

					client_info.openid = inf.openid
					client_info.game = inf.game
					client_info.machid = inf.machid
					client_info.pos = k
					client_info.g_state = const.game_state.logout
					client_info.countdown = const.basket_state_t.login_t
					client_info.mode = inf.game_mode
					iotagent.changegamestate(client_info)

					--logger.info("return2 logout")
					--print("inf.openid:"..inf.openid.."qrscene:"..qrscene)
					
					--退出微信端用户
					skynet.call(service.wechathttpc,"lua","logout",inf.openid,qrscene)
					--iot的openid清空
					iotagent.setopenid(k,nil)
				end
			else
			end
		end

		skynet.sleep(30)
	end
end

function iotagent.assign(fd,mach,pos)

	if data.fd == nil then
		data.fd = fd
	else 
		skynet.error("fd %s is assigned", data.fd)
		assert(data.fd == fd)
	end

	iotagent.add(fd,mach,pos)

	skynet.fork(new_message, fd)
	
	return true
end

skynet.start(function()
	const = query_sharedata "const"
	skynet.fork(state_update)
end)

service.init {
	command = iotagent,
	info = data,
	require = {
		"iotmanager",
		"wechathttpc",
	},
}

