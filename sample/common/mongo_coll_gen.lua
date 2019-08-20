local M = {}

--[[
	该文件记录服务器中用到的mongodb collection的生成函数和文档, 方便后期文档生成
	文档记录：
		*. 函数参数说明
		*. 记录collection的所有doc可能出现的字段
]]

--[[
本文档是mongodb所有的文档的定义，要求如下：
 * 每个字段都必须在此备注; 
 * 字符串用"xxx"; 
 * 数字用123; 
 * _id字段必须写明是什么数据，比如$outerid; 
]]

--[[
用户id映射关系:
outerid即外部平台的id，如QQ、微信的unionid（以前叫openid）、手机号;
openid即平台账号id，与outerid一一对应的；
uid即游戏账号id，ios跟android有不同的uid，与捕鱼来了类似，不同手机平台不同uid；
outerid --> openid   --> ios_uid
                                    --> android_uid

account_plat can be qq \ wc \ phone \ lk \ test
]]
function M.outerbind(account_plat)
	--[[		
		{
			_id =  "$outerid",    --1)以前的openid，但现在统一用unionid（比openid更通用） 2) 手机号
			openid = "xxx",	
			[token] = "xxx", 	      --密码, 不一定有，目前手机登录才有
		}
	]]
	return string.format("outerbind_%s", account_plat)
end

--openid --> uid
function M.userbind()
	--[[
		{
			_id = "$openid",
			uid_0 = xxx,   -- for ios   --index
			uid_1 = xxx,   -- for android  --index
		}
	]]
	return string.format("userbind")
end

--共同自增id
function M.common_inc_id()
	--[[	
		{
			_id = "$idtype",
			id_value = 123,
		}
	]]
	return "common_inc_id"
end

function M.open_info()
	--[[
		{
			_id = "$openid",
			memberid = 123,  --index
			nickname = "xxx",
			gender = "x",   --m or f
		}
	]]
	return "open_info"
end

--用户基础数据（除了邮箱、背包、好友、历史记录等之外的都存这里）
function M.user_basic()
	--[[
		{
			_id = $uid,
			diamond = 0,
			level = 0,
			exp = 0,
			win_ctrl = {  			--输赢控制
				base_coin,      		--娃娃基准    会出现负数
				all_game_times,             --游戏总次数
				catch_coin_value,           --总抓中娃娃的价值
				all_pay_coin,		--玩家充值的娃娃币总量
				miss_catch_coin,            --未抓中消耗，自上次抓中以来
				miss_catch_times,          --未抓中次数
				ctrl_version,	             --控制的版本
			},
		}
	]]
	return "user_basic"
end

function M.backpack()
	--[[
		{
			_id = $uid,
			["id1"] = {quantity = 0},
			["id2"] = {quantity = 0},
			["id3"] = {quantity = 0},
			-- ...
		}
	]]
	return "backpack"
end

function M.sys_mail()
	--[[
		{
			{
				_id = $uid,
				list = [
					{
						id = xx,
						mtype = 0,
						create_time = 0,
						bonus = {...},
						expired_time = 0,
						title = 'xxx',
						body  = 'xxx',
						extra_msg = {...},
					},
					...
				]
			},
			...
		}
	]]
	return "sys_mail"
end

--支付定单
function M.pay_order()
	--[[
		{
			order_id = "xxxxx",
			....
		}
	]]
	return "pay_order"
end

--房间列表
function M.room_list()
	--[[
		{
			_id : $room_id,                                 --房间id, integer
			doll_id : $doll_id,                             --公仔id
			room_type : xxx,		   --房间类型, integer  const.room_type: 1 fix_price; 2 practice
			play_cost : xxx, 			   --每次玩扣多少币, integer
			mgr_status: xxx, 		   --管理状态, integer  (后台配置)
			round_time: xxx,           		   --每局限时（秒）
			"ad" : xxx,		                 --内置广告编号
			"gm_status" : xxx, 		   --gm状态
			"creator_account" : "xxx",  --
			"create_time" : xxx,


			running_status : xxx,                       --运行状态, integer (实际运行中状态)
			now_wawaji_id : $wawaji_id,        --当前关联的娃娃机id（此值由房间服务器自己匹配，不得外部设置）
			wawaji_stream_id1 : "xxx"	  --娃娃机的视频流id1
			wawaji_stream_id2 : "xxx"	  --娃娃机的视频流id2
			user_stream_id 2     : "xxx"	  --用户的视频流id
		}
	]]
	return "room_list"
end

--公仔列表
function M.doll_list()
	--[[
		{
			_id : $doll_id,                --公仔id, integer
			doll_url : "xxx",             --图片地址
			doll_cost : xxx,              --成本，一个记录值而已
			doll_name : "xxx"				-- 娃娃名称
			creator_account : "xxx" 		-- 创建账户
			create_time : xxx 				-- 创建时间
		}

	]]
	return "doll_list"
end

--娃娃机列表
function M.wawaji_list()
	--[[
		{
			_id : $wawaji_id,                --娃娃机id, integer
			token : "xxx",                      --登录密码(裸的，不要任何加密，需要展示给娃娃机管理者，用于登录的)
			doll_id : $doll_id,                --公仔id
			mgr_status : xxx, 	   --管理状态, integer  (后台配置)
			"wawa_cnt": xxx,			-- 娃娃数量
			"warning_value": xxx,		-- 警告值
			"area":"xxx",				-- 所属区域
			creator_account: "xxx",
			create_time: xxx,
		}
	]]	
	return "wawaji_list"
end

function M.pay_order_trans()
	--[[
		{
			order_id:xxx
			uid : xxx,
			product: 0,
			diamond:10,
			plat_id: 2	
		}
	]]
	return "pay_order_trans"
end

--玩家好友关系
function M.friend()
	--[[
		{
			_id: $openid,
			friendship: [		-- 好友关系
				{openid: $openid, rel_type: xx, create_time: xxx},
				...
			]
			ext_nfriend: xx,			-- 外部好友个数
			int_nfriend: xx,			-- 内部好友个数
			recv_reqs: [		-- 收到其他玩家的请求
				{openid: $openid, create_time: xxx},
				...
			]
			n_recvreqs: xx,		-- 收到的请求数目
			sended_reqs: [		-- 发送出去的好友请求数
				{openid: $openid, create_time: xxx},
				...
			]
		}
	]]
	return "friend"
end

--用户游戏结果
function M.user_play_result()
	--[[
		{
			_id: obj_id
			uid: $uid
			room_id: $room_id
			round_id: xxx
			doll_id: $doll_id
			wawaji_id: $wawaji_id
			begin_time: xxx
			end_time: xxx
			result: xxx
		}
	]]
	return "user_play_result"
end

--娃娃没有上报结果的记录
function M.wawaji_fail_report_record()
	--[[
		{
			_id: objid,
			wawaji_id: $wawaji_id
			uid: $uid,
			room_id: $room_id
			round_id: 
			doll_id: $doll_id
			begin_time: xxx
			end_time: xxx			
		}
	]]
	return "wawaji_fail_report_record"
end

return M
