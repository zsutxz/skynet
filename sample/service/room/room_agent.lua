require "skynet.manager"
require "functions"
local skynet = require "skynet"
local skynet_util = require "skynet_util"
local logger = require "logger"
local futil = require "futil"
--local dataproxy = require "dataproxy"
local query_sharedata = require "query_sharedata"

local print_t = require "print_t"

local room_id = tonumber(...) or error(string.format("invalid room_id %s", tostring(...)))
local CMD = {}
local const
local ec
local room_const

local ctx = {
	state = nil,		--游戏状态
	is_loaded = false,
	room_id = room_id,
	users = {},
	create_t = 0,			--房间创建时间点
	matching_t = 0,			--房间匹配总时长
	last_preserve_time = 0,
	last_preserve_uid = nil,
	team = 0,				--1、2对
}

function CMD.get_player_num()

	local count = 0

	-- if ctx~=nil and ctx.users~=nil then
	-- 	count = #(ctx.users)
	-- end

	for k,v in pairs(ctx.users) do
		count = count + 1
	end
	
	--logger.info("get_player_num: %d", count)

	return count
end

function CMD.get_room_state()
	return ctx.state
end

function CMD.init(args)
	ctx.state = args.state
	ctx.create_t = args.create_t
	ctx.matching_t = args.matching_t
end

--返回房间的剩余时间
function CMD.add_user(user_info,num)

	--slogger.info("add_user, user openid:%s,mode:%s", user_info.openid,user_info.mode)
	local info = {}
	
	if user_info.mode == const.game_mode.net_team then
		info.team = num%2 + 1	--属于哪个个队
	else
		info.team = 0
	end

	info.openid = user_info.openid
	info.mach = user_info.game..user_info.machid
	info.pos = user_info.pos
	info.score = 0
	info.rank = 0
	info.mode = user_info.mode
	info.g_state = const.game_state.matching

	ctx.users[user_info.openid] = info

	local remain_t = ctx.matching_t - (os.time() - ctx.create_t)
	
	if remain_t>0 then

		info.g_state = const.game_state.matchok
		ctx.users[user_info.openid] = info

		return info.team,remain_t
	else
		return nil
	end
end

function CMD.canstart()	
	if ctx.state == const.room_state.matching then
		if CMD.get_player_num()>=const.room.max_player or os.time() - ctx.create_t>=ctx.matching_t then
			ctx.state = const.room_state.matchok 
			--print("in canstart,state:"..ctx.state.." ctx.create_t:"..ctx.create_t.."ctx.matching_t:"..ctx.matching_t)
			return true
		end
	end

	return false
end

function CMD.startgame()

	logger.info("room %s startgame, playernum:%d",ctx.room_id,CMD.get_player_num())

	local iotmanager = skynet.uniqueservice("iotmanager") 
	for k,v in pairs(ctx.users) do
		--获取游戏设备agent
		local iotagent = skynet.call(iotmanager,"lua","getagent",v.mach,v.pos)

		if v.g_state==const.game_state.matchok then
		   --print_t(v)
			if 1 == CMD.get_player_num() then
				v.mode = const.game_mode.net_single
				ctx.users[k].mode = v.mode
			end
			local ret = skynet.call(iotagent,"lua","startgame",v.pos,ctx.users[k].mode)

			if ret == false then
				logger.info("startgame,player %s no ready", k)
				return false
			else
				ctx.users[v.openid].g_state = const.game_state.play
			end
		end
	end

	--有玩家还没有匹配成功，返回false
	if ctx.state == const.room_state.matchok then
		for k,v in pairs(ctx.users) do
			if v.g_state==const.game_state.matching then
				return false
			end
		end
		--所有玩家都匹配成功，房间切换到游戏。
		ctx.state = const.room_state.play
	end

	return true
end

local function sortscore()
	for k1,v1 in pairs(ctx.users) do
		local rank = 1
		for k2, v2 in pairs(ctx.users) do
			if k1 ~= k2 and v1.score< v2.score then
				rank= rank + 1
			end
			ctx.users[k1].rank = rank
 		end
	end
end

function CMD.update_score(openid,score)
	if ctx.users[openid]~=nil and ctx.users[openid].score ~= score then
		ctx.users[openid].score = score
		sortscore()
	end
	return ctx.users
end
 
function CMD.getteamrank(team,openid)
	local rank = 1
	
	for k,v in pairs(ctx.users) do
		if k ~= openid and ctx.users[openid].socre< v.score and ctx.users[openid].team == v.team then
			rank = rank+1
		end
	end

	return rank
end

function CMD.getteamallsocre(team)
	local allscore = 0
	for k,v in pairs(ctx.users) do
		if v.team==team then
			allscore = allscore + v.score
		end
	end
	return allscore
end

function CMD.getfinal()
	sortscore()
	local ret = {}

	for k,v in pairs(ctx.users) do
		local info = {} 
		info.openid = k
		info.rank = v.rank
		info.point = v.score
		info.pos = v.pos
		ret[k] = info
	end

	return ret
end

--指定玩家结束了游戏,更新游戏分数
function CMD.setuserover(openid,score)
	ctx.users[openid].score = tonumber(score)
	ctx.users[openid].g_state = const.game_state.over
		
	--print("setuserover,openid:"..openid.." score:"..ctx.users[openid].score.." g_state:"..ctx.users[openid].g_state)

	return true
end

--房间游戏是否结束
function CMD.isover()
	if ctx.state == const.room_state.play then
		for k,v in pairs(ctx.users) do
			if v.g_state==const.game_state.play then
				return false
			end
		end
		--所有玩家都结束了游戏
		ctx.state = const.room_state.over
		return true
	end
	return false
end

--结束游戏,进入结算画面
function CMD.stopgame()
	logger.info("in room %s want to stopgame", ctx.room_id)

	local iotmanager = skynet.uniqueservice("iotmanager") 
	for k,v in pairs(ctx.users) do
		--获取游戏设备agent
		local iotagent = skynet.call(iotmanager,"lua","getagent",v.mach,v.pos)

		if v.g_state==const.game_state.over then
			v.countdown = const.basket_state_t.over_t
			local ret = skynet.call(iotagent,"lua","stopgame",v)

			if ret == false then
				logger.info("player %s stopgame:no ok", k)
				return false
			end
		end
	end

	return true
end

-- function CMD.close()
-- 	logger.info("close room_agent")

-- 	skynet.exit()
-- end

skynet.init(function ()
	const = query_sharedata "const"
	assert(const)

	ec = const.room_error_code
	room_const = const.room

	assert(ec)
	assert(room_const)

end)

skynet.start(function ()
	--logger.info("room_agent starting, room_id = %s", ctx.room_id)
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command11 %s", tostring(cmd)))
		end
	end)

	skynet.register(".roomagent_"..ctx.room_id)
	logger.info("room_agent started, room_id = %s", ctx.room_id)
end)
