local skynet = require "skynet"
require "skynet.manager"
require "functions"
local skynet_util = require "skynet_util"
local logger = require "logger"
local futil = require "futil"
local query_sharedata = require "query_sharedata"
local json = require "json"
local cache_util = require "cache_util"
local sqlutil = require "sqlutil"
--local conf_util = require "conf_util"
local print_t = require "print_t"

local CMD = {}
local globalconf
local const

local all_room = {}
local starting_room = {}

--已经加入到任何房间的用户
local room_openid = {}

--多人赛，等待加入房间的玩家
local rank_user_waiting = {}
--组队赛，等待加入房间的玩家
local team_user_waiting = {}

--多人赛最后一个房间,从1开始，用来自增生成房间
local rank_last_id = 1
--组队赛最后一个房间,从1开始，用来自增生成房间
local team_last_id = 1

local function create_room(mode,room_id,remain_t)
	local agent = skynet.newservice("room_agent", room_id)
	local now_t = os.time()
	
	local args = {state = const.room_state.matching,create_t = now_t, matching_t = remain_t}
	skynet.call(agent,"lua","init",args)
	
	local room_info = {room_id = room_id,mode = mode,agent = agent}
	all_room[room_info.room_id] = room_info
	
	starting_room[room_id] = nil

	--写入到数据库
	local sqlarg = {room_id = room_id,name = "test",time = os.date("%Y%m%d%H%M%S", now_t)}
	local res = cache_util.call('wx_db', 'insert_room', sqlarg)
	
	if res then
		return {errmsg = 'write db ok',errcode = 0}
	else
	    logger.err("insert_room sql err")
        return {errmsg = 'DB error',errcode = 2}
    end
end

--搜索mode模式的最后一个房间，如果最后一个房间满人，则给一个最大的id+1。
local function search_room(mode)
    local num = 0
	local temp_id = 0
	local room_state = 0
	if mode == const.game_mode.net_rank then
		temp_id = rank_last_id
	elseif mode == const.game_mode.net_team then
		temp_id = team_last_id
	end
	
	if all_room[temp_id] ~= nil then	
		local agent = all_room[temp_id].agent
		num = skynet.call(agent, "lua", "get_player_num")
		room_state = skynet.call(agent,"lua","get_room_state")
	end

	--满人,或room是空的，给一个新id。
	if num >= const.room.max_player or room_state>=const.room_state.matchok or all_room[temp_id] == nil then
		if rank_last_id > team_last_id then
			temp_id = rank_last_id + 1
		else
			temp_id = team_last_id + 1
		end
		num = 0
	end

	logger.info("in search_room,roomid:%s,player num:%d",temp_id,num)
	
	return temp_id,num
end

--remain_t:创建房间时，房间的剩余时间
function CMD.join_room(user_info,remain_t)

	--房间人数
	local player_num = 0
	local room_id = 0
	local mode = user_info.mode
	local waiting_num = 0
	local ret = {}
	
	--用户已经加入房间
	if room_openid[user_info.openid] == true then
		return nil,0  --返回房间号0,表示玩家已经加入其他房间
	end

	--获取到的人数一定小于const.room.max_player
	room_id,player_num = search_room(mode)
	
	if mode == const.game_mode.net_rank then

		rank_user_waiting[user_info.openid] = os.time()
		
		--计算等待人数
		for k,v in pairs(rank_user_waiting) do
			--等待时间太久的玩家
			if v ~= nil and os.time() - v > remain_t + 1 then
				rank_user_waiting[k] = nil
				print("clear rank_user_waiting:"..k)
			else
				waiting_num = waiting_num + 1
			end
		end	
				
		--需要创建房间
		if player_num==0 and waiting_num>1  then
			if room_id > rank_last_id then
				rank_last_id = room_id
			end
			--print("rank_last_id:"..rank_last_id.." room_id:"..room_id)

			ret = create_room(mode,room_id,remain_t)
			if ret.errcode ~= 0 then
				--创建房间失败
				return nil
			end
		end

		--只有人数大于1才能进入房间
		if player_num + waiting_num > 1 then
			--找到对应的房间	
			local agent = all_room[room_id].agent

			if agent ~= nil then			
				local team,remaining_t = skynet.call(agent, "lua", "add_user",user_info,player_num)
				if remaining_t == nil then
					rank_user_waiting[user_info.openid] = nil
					room_openid[user_info.openid] = true
					logger.info("add_user error：remaining not enough time,room_id:%s",room_id)
				else
					rank_user_waiting[user_info.openid] = nil
					logger.info("%s,join_room ok, room_id:%s,team:%s,remaining time:%s",user_info.openid,room_id,team,remaining_t)
					return true,room_id,mode,team,remaining_t   --返回房间号和组队号,剩余时间
				end
			else
				logger.info("join_room error no room,room_id:%s,openid:%s",room_id,user_info.openid)
			end	
		else
			--人数不够
			logger.info("room has no enough player")
			return nil
		end	
	elseif mode == const.game_mode.net_team then		
	
		team_user_waiting[user_info.openid] = os.time()
		
		--计算等待人数
		for k,v in pairs(team_user_waiting) do
			--等待时间太久的玩家
			if v ~= nil and os.time() - v > remain_t + 1 then
				team_user_waiting[k] = nil
				print("clear team_user_waiting:"..k)
			else
				waiting_num = waiting_num + 1
			end
		end	

		--print("player_num:"..player_num.." waiting_num:"..waiting_num)

		--需要创建房间
		if player_num==0 and waiting_num>1  then
			if room_id > team_last_id then
				team_last_id = room_id
			end
			
			--print("team_last_id:"..team_last_id.." room_id:"..room_id)

			ret = create_room(mode,room_id,remain_t)
			--print("ret.errcode:"..ret.errcode)
			if ret.errcode ~= 0 then
				--创建房间失败
				return nil
			end
		end

		if waiting_num<2 and (player_num + waiting_num)%2==1 then
			logger.info("room has no 2*player,room_id:%s,openid:%s",room_id,user_info.openid)
		elseif player_num + waiting_num>1 then
			--找到对应的房间	
			local agent = all_room[room_id].agent

			if agent ~= nil then			
				local team,remaining_t = skynet.call(agent, "lua", "add_user",user_info,player_num)
				if remaining_t == nil then
					team_user_waiting[user_info.openid] = nil
					logger.info("add_user error：remaining not enough time,room_id:%s",room_id)
				else
					team_user_waiting[user_info.openid] = nil
					room_openid[user_info.openid] = true
					logger.info("%s,join_room ok, room_id:%s,team:%s,remaining time:%s",user_info.openid,room_id,team,remaining_t)
					return true,room_id,mode,team,remaining_t   --返回房间号和组队号,剩余时间
				end
			else
				logger.info("join_room error no room,room_id:%s,openid:%s",room_id,user_info.openid)
			end
		else
			--人数不够
			logger.info("room has no enough player")
			return nil
		end	
	end
	
	return nil
end

--更新指定房间，返回玩家排名，和排名最高的玩家的分数
function CMD.update_score(room_id,openid,score)
	local selfrank = 0
	local highestscore = 0

	local agent = all_room[room_id].agent
	
	if agent~=nil then
		--把指定玩家的信息写到分数李彪，再获取全部玩家的信息
		local ret = skynet.call(agent, "lua", "update_score",openid,score)
		if ret ~= nil then
			--print_t(ret)
			for k,v in pairs(ret) do
				if k==openid then
					selfrank = v.rank
				end
				
				if v.rank==1 then
					highestscore = v.score
				end
			end
		end
	end

	return highestscore,selfrank
end

--获取每个组的分数
function CMD.getteamallsocre(room_id,team)
	local agent = all_room[room_id].agent
	local ret = nil

	if agent~=nil then
		ret = skynet.call(agent, "lua", "getteamallsocre",team)
	end
	
	return ret
end

--获取指定openid组内排名
function CMD.getteamrank(room_id,team,openid)
	local agent = all_room[room_id].agent
	local ret = nil

	if agent~=nil then
		ret = skynet.call(agent, "lua", "getteamrank",team,openid)
	end
	
	return ret
end

--openid登录的硬件端，结束了游戏,把数据传输过来。
function CMD.iotsetuserover(room_id,openid,score)
	
	--print("iotsetuserover,room_id:"..room_id.." openid:"..openid.." score:"..score)

	local agent = all_room[room_id].agent
	local ret = nil
	
	if agent ~= nil and score ~= nil then
		ret = skynet.call(agent, "lua", "setuserover",openid,score)
	end
	return ret
end

--获取本房间的最终排名
function CMD.getfinalresult(room_id)
	local agent = all_room[room_id].agent
	local ret = nil
	
	if agent~=nil then
		ret = skynet.call(agent, "lua", "getfinal",room_id)
	end

	return ret
end

local function check_start()
	for k,v in pairs(all_room) do
		if starting_room[k]==nil and true==skynet.call(v.agent, "lua", "canstart") then
			local ret = skynet.call(v.agent, "lua", "startgame") 
			if ret == true then
				starting_room[k] = true
			end
		end
	end
end

local function remove_room(room_id)
	assert(room_id)

	local agent = all_room[room_id].agent

	if agent ~= nil then
		local info = skynet.call(agent, "lua", "getfinal",room_id)
		for k,v in pairs(info) do
			room_openid[v.openid] = nil
		end
		
		skynet.kill(agent)

		-- local temp = ".roomagent_"..room_id
		-- skynet.call(temp, "lua", "close")

		all_room[room_id] = nil
		starting_room[room_id] = nil

		logger.info("remove_room:%s",room_id)
	else
		logger.info("remove_room:agent is null")
	end
	
end

local function check_over()
	for k,v in pairs(all_room) do
		local ret = skynet.call(v.agent, "lua", "isover") 
		if ret == true then
			ret = skynet.call(v.agent, "lua", "stopgame") 
			if ret == true then
				logger.info("room %s stopgame:ok", v.room_id)
				remove_room(v.room_id)
			end
		end
	end
end

--游戏主玩法循环
local function room_update()
	while true do
		skynet.sleep(const.room.check_play_interval*100)
		--if 
		xpcall(check_start, skynet_util.handle_err)

		xpcall(check_over, skynet_util.handle_err)
	end
end

--最大的一个房间，在启动时，从数据库读取，避免再次创建的房间冲突。
local function getmaxroomid()

	--查询最大记录
	local sqlarg = {}
	local last_id = 0
	local res = cache_util.call('wx_db', 'select_last_room_id', sqlarg)

	if not res then
		logger.err("select_last_room_id sql err")
		return nil
	end
		
	if #res == 1 and res[1] ~= nil and res[1].last_id then
	  --print("res.max_id:"..res[1].last_id)
		last_id = res[1].last_id
	else
		last_id = 1
	end
	
	return last_id
end

skynet.init(function ()
	globalconf = query_sharedata "globalconf"
    const = query_sharedata "const"
end)

skynet.start(function ()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command11 %s", tostring(cmd)))
		end
	end)

	--重启，处理两个id，使得与原来的不重复。	
	rank_last_id = getmaxroomid()
	team_last_id = rank_last_id
	--print("rank_last_id:"..rank_last_id.." team_last_id:"..team_last_id)
	skynet.fork(room_update)

	skynet.register(".room_mgr")
end)

