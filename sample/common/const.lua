local logger_const = require "logger_const"
local i18 = require "i18_ch"

local const = {}

const.PTYPE = require "ptype"

const.log_level = logger_const.log_level
const.log_lvlstr = logger_const.log_lvlstr
const.rolling_type = logger_const.rolling_type

const.server_status = {
	initing = 1,
	running = 2,
	maintaining = 3,
}

const.master_lock = {
	lock_default_ex = 45,		--默认失效时间
	check_lock_time = 5,		--检查锁的时间
	master_wait_cycle = 3,      	--获得master锁之后，要等待多少个检测循环才开始做master做的事
	outpub_cycle = 20,          	--隔多少个循环输出一次自己的cnt
}

const.login_queue = {
	max_login_per_sec = 50,	--默认每秒最多登录请求
}

--排行榜类型到单实例redis的映射，目前配置了3个单实例rankredis, 1 ~ 3
const.ranktype_2_rankredis = {
	test_rank = 1,
}

const.phone_plat = {
	ios = 0,
	android = 1,
	gamemachine = 2,
}

const.support_phone_plat = {
	[const.phone_plat.ios] = true,
	[const.phone_plat.android] = true,
	[const.phone_plat.gamemachine] = true,
}

const.account_plat = {
	qq = "qq",		--qq
	wc = "wc", 		--微信
	guest = "guest", 	--ios guest
	phone = "phone",           --phone number
	test = "test",                     --test账号(robot_xxx)
}

const.wawaji_account_plat = {
	lk = "lk", 		
}

const.watchdog = {
	clear_zombie_agent_interval = 5,
	clear_zombie_agent_max_wait = 40,
	agent_keep_alive = 5,
	agent_dead_time = 10,
	to_adjust_online_user_count = 10, 		-- 定时纠正在线人线(秒)
	silent_kick_cnt_once = 3,   			-- 静默踢人每n秒踢人的人数
	silent_kick_sleep_interval = 1, 			-- 静默踢人每次休眠秒数
	silent_kick_output_cnt = 10, 			-- 静默踢人每n人进度输出
}

const.agent = {
	max_wait_logout = 30,				--等待logout最长时间
	kick_not_login = 30,				--踢掉连接了而不发起登录的用户(秒)
}

const.cmd_stat = {
	default_output_interval = 900,			--默认输出间隔
}

const.check_active = {
	default_interval = 10,
}


const.heartbeat =
{
	timeout = 30, 					-- 超时时间
	send_interval = 15, 				-- s2c发送间隔
	check_time = 	25, 				-- 服务器检测间隔
	phone_sleep_timeout = 600, 			-- ios游戏切换到后台特殊处理
}

const.db = {
	default_save_interval = 120,			--默认回写间隔(秒)
	core_bgsave_interval = 120,			--核心数据回写间隔
	non_core_bgsave_interval = 180,	   	--非核心数据回写间隔
	max_bgsave_queue_len = 5,			--最大的回写队列长度
}

const.profile = {
	mem_sampling_interval = 60,			--内存采样间隔（秒）
}

--agent循环调用的间隔（秒）
const.agent_repeat_interval = {
	gc = 30,						--gc
	check_inactive_and_kick = 15,			--检查不活跃并踢人
	report_online_time = 300,
	check_player_room_limit = 300,
	check_exp_room_balance = 120,
}

const.login_outerid_error_code =
{
	ok = 0,						--成功
	invalid_argu = 1,				--参数有错误
	user_not_exists = 2,				--用户不存在
	invalid_user_or_token = 3,			--outerid或token无效,（请重新拉取授权）
	http_req_fail = 4, 				--连接msdk服务器执行请求失败
	http_data_error = 5,				--msdk服务器返回数据错误无法解析
	account_plat_not_support = 7,			--账号平台不支持 (qq, wc, guest, phone, test)
	phone_plat_not_support = 8,  			--手机平台不支持（0 ios, 1 android)
	server_is_maintaining = 9,			--服务器正在维护
	server_is_notinited = 10,			--服务器正在启动
	server_error = 11,				--服务器错误
	version_too_old = 12,				--版本过低
	version_ahead = 13,				--版本号超前
	userAlreadyInRoom = 14,			--用户已经在房间中
	ios_redirect = 15, 				--ios审核版本要跳转
	banned = 16,					--被封号
	not_in_whitelist = 17, 				--白名单限制开启了，用户不在白名单中
	max_reg_user_limit = 18,			--达到游戏配置的最大注册人数限制
	create_user_fail = 19,				--创建游戏用户失败
	duplicate_login = 20,				--重复登陆
	invalid_midas_arg = 21,				--midas参数非法
	exiting = 22,					--账号正在退出
	too_many_user = 23,                 			--总人数过多
	android_redirect = 24,              			--android审核版本跳转
	fail_create_memberid = 25, 			--创建memberid失败
	fail_create_openinfo = 26, 	                            --创建openinfo失败
	invalid_regist_arg = 27,				--无效的注册信息
	invalid_verify_code = 28,			--无效的手机检验码
	phone_already_bind = 29,			--注册失败，手机已经绑定
	invalid_passwd = 30,				--用户密码错误
	invalid_phone_num = 31,			--无效的手机号
	fail_to_get_openinfo = 32,                                       --can't get openinfo
}

const.login_outerid_error_code_desc =
{
    [const.login_outerid_error_code.too_many_user] = i18[1],
    [const.login_outerid_error_code.not_in_whitelist] = i18[2],
    [const.login_outerid_error_code.banned] = i18[22],
}

const.login_wawaji_id_error_code =
{
	ok = 0,						--成功
	invalid_argu = 1,				--参数有错误
	user_not_exists = 2,				--用户不存在（服务器错误）
	account_plat_not_support = 3,                                --账号平台不支持 (lk, test)
	userAlreadyInRoom = 4,			--用户已经登录
	server_is_maintaining = 5,			--服务器正在维护
	server_is_notinited = 6,				--服务器正在启动
	server_error = 7,				--服务器错误
	duplicate_login = 8,				--重复登陆
	exiting = 9,					--账号正在退出
	version_too_old = 10,				--版本过低
	version_ahead = 11,				--版本号超前
	too_many_user = 12,                 			--总人数过多
	invalid_pwd = 13,				--
	invalid_wawaji_id = 14,				--
}




const.login_wawaji_id_error_code_desc = {
	
}

const.login_machine_id_error_code =
{
	ok = 0,						--成功
	invalid_argu = 1,				--参数有错误
	user_not_exists = 2,				--用户不存在（服务器错误）
	account_plat_not_support = 3,                                --账号平台不支持 (lk, test)
	server_is_maintaining = 5,			--服务器正在维护
	server_is_notinited = 6,				--服务器正在启动
	server_error = 7,				--服务器错误
	duplicate_login = 8,				--重复登陆
	exiting = 9,					--账号正在退出
	version_too_old = 10,				--版本过低
	version_ahead = 11,				--版本号超前
	too_many_user = 12,                 			--总人数过多
	invalid_pwd = 13,				--
	invalid_wawaji_id = 14,				--
}

const.login_machine_id_error_code_desc=
{
	ok = 0,						--成功
	invalid_argu = 1,				--参数有错误
	user_not_exists = 2,				--用户不存在（服务器错误）
	account_plat_not_support = 3,                                --账号平台不支持 (lk, test)
	server_is_maintaining = 4,			--服务器正在维护
	server_is_notinited = 6,				--服务器正在启动
	server_error = 7,				--服务器错误
	duplicate_login = 8,				--重复登陆
	exiting = 9,					--账号正在退出
	version_too_old = 10,				--版本过低
	version_ahead = 11,				--版本号超前
	too_many_user = 12,                 			--machine过多
	invalid_pwd = 13,				--
	invalid_machine_id = 14,				--
}

const.backpack_error_code = {
	ok = 0,
}

const.version = {
	update_ver_len = 3,		-- 更新版本线长度
	compatible_ver_len = 2, 	-- 兼容版本线长度
}

const.version_list = {
	t = "1.0", 			-- 公测
}

const.kick_user_errorcode =
{
	ok = 0,
	fail = 1,
	system_error = 2,
}

--更新包类型
const.update_package_type = {
	res_pack = 1,   --资源包
	full_pack = 2,	--整包
}

--更新类型
const.update_update_type = {
	noneed_update = 0,	--不需要更新
	optional_update = 1, 	--可选更新
	must_update = 2,     	--必须更新
	conf_update = 3,     	--配置强制更新
}

const.gender =
{
	male = "m",				-- 男性
	female = "f",				-- 女性
	default = "m",				-- 默认性别
}

const.pic_id = {
	url = 0,                				--url image
	pic1 = 1,               				--系统头像, large then 0
	invalid_pic = 101,      				--max pic id, 不能使用
}

const.sms_verify = {
	expire = 600,                  		 		-- 10 minute
	err = {
		success = 0,
		mobile_err = 1,             
		svr_err = 2,                    			--服务器执行错误
		bussiness_limit = 3,            		--alidayu bussiness limit, 阿里大于逻辑限制(发送过于频繁)
		error_response = 4,             		--decode response,got 'error_response', 服务器错误
		already_used = 5,               		--手机已经被使用
	},
}

const.sms_verify_type = {
	regist = 0,
	verify = 1
}

--最大注册人数限制定义
const.max_register_count_def = {
	no_limit = -1,				-- 没有限制
	forbid = 0,		    		-- 不允许注册
}

--踢人的原因
const.kick_reason = {
	login_other_place = 0,			--别处登录
	server_is_shutdowning = 1,		--停服
	admin_kick = 2,				--管理员踢下线
	heartbeat_timeout = 3,			--心跳超时 (不会弹窗提示，可以断线重连)
	req_timeout = 4,			--请求超时 (不会弹窗提示，可以断线重连)
	idip_kick = 5,				--idip踢人
	may_cheating = 6, 			--作弊嫌疑踢人
	cheating = 7, 				--作弊踢人
	fast_msg = 8,     			--请求过于频繁
	inactive_long_time = 9,     		--长时间不活跃，踢下线 (不会弹窗提示，可以断线重连)
}

const.kick_msg = {
	[const.kick_reason.login_other_place] = i18[4],
	[const.kick_reason.server_is_shutdowning] = i18[5],
	[const.kick_reason.admin_kick] = i18[6],
	[const.kick_reason.heartbeat_timeout] = i18[7],
	[const.kick_reason.req_timeout] = i18[8],
	[const.kick_reason.may_cheating] = i18[9],
	[const.kick_reason.cheating] = i18[10],
	[const.kick_reason.fast_msg] = i18[11],
	[const.kick_reason.inactive_long_time] = i18[12],
}

const.user_pos = {
	expire = 180,			--seconds
	update_interval = 90,		--seconds
}

const.wawaji_pos = {
	expire = 180,			--seconds
	update_interval = 90,		--seconds	
}

--用户的基础字段（除了邮箱、背包、好友、及一些历史记录之外，都放这里）
--!!最多只支持一层嵌套，比如win_ctrl!!
--每个字段都要给出默认值
const.user_basic_field_def = {
	diamond = 0, 			--钻石
	level = 0,			--等级
	exp = 0,			--经验
	gold = 0, 			--金币
	ban_info = {
		ban_flag = 0,
		ban_idip = 0,
		ban_start_time = 0,
		ban_time = 0,
		ban_reason = '',
		ib_start_time = 0,
	},
	win_ctrl = {  			--输赢控制
		base_coin = 0,      		--娃娃基准, 会出现负数
		all_game_times = 0,             	--游戏总次数
		all_catch_coin = 0,           	--总抓中娃娃的价值
		all_recharge_coin = 0,		--玩家充值的娃娃币总量
		miss_coin_since_last = 0,            	--未抓中消耗，自上次抓中以来
		miss_times_since_last = 0,          	--未抓中次数，自上次抓中以来
		ctrl_version = 1,	             		--控制的版本
	},
}

--用户的基础字段哪些要定时回写的
--!!最多只支持一层嵌套，比如win_ctrl!!
const.user_basic_field_bgsave = {
	diamond = true,
	level = true,
	exp = true,
	gold = true,
	win_ctrl = {  			
		base_coin = true,
		all_game_times = true, 
		all_catch_coin = true,
		all_recharge_coin = true,
		miss_coin_since_last = true,
		miss_times_since_last = true,
		ctrl_version = true,
	},
}

--用户的基础字段一些回写的阀值
const.user_basic_field_bgsave_threshold = {
	diamond = 1,
	level = 1,
	exp = 1000,
	gold = 1000,
}

--公告级别
const.msgsvr_msg_level = {
	svr_shutdowning = 0,		--停服公告
	urgency = 1,			--紧急公告
	normal = 2,			--一般公告
}

--获取客户端更新信息错误码
const.get_update_info_error_code = {
	ok = 0,					--成功
	not_in_whitelist = 1,			--用户不在白名单之中 (废弃)
	invalid_phone_plat = 2, 			--参数错误：无效的手机平台
	no_conf = 3,				--服务器没有配置
	server_error = 4,			--服务器错误
	update_limited = 5, 			--此版本的客户端被限制更新
}

const.version_bonus_const = {
	check_ver_N = 3,			-- 检测版本号的前N位
}

const.general_error_code = {
	ok = 0, 			-- 成功
}

const.room_error_code = {
	ok = 0,						--成功		
	server_error = 1,				--服务器错误			
	invalid_argu = 2,				--参数错误
	chat_too_often = 3, 				--聊天消息过快
	not_in_room = 4,				--不在房间中
	room_not_idle = 5, 				--房间当前不可用
	not_enough_money = 6,			--币不足
	dec_money_fail = 7,				--扣钱失败
	invalid_player = 8,				--已经不是操作者
	invalid_play_time = 9,				--已经不在操作时间内
	wawaji_failure = 10,				--娃娃机故障
	room_has_no_wawaji = 11,			--当前房间没有可用娃娃机
	invalid_wawaji_id = 12,				--无效的wawaji id
	invalid_roundid = 13,				--无数的游戏局id
	report_timeout = 14,				--娃娃机上传数据已经超时
	others_will_play = 15,				--其他人领先一步，即将开始游戏
	invalid_machine_id = 16,			--无效的machine_id

}

const.test_error_code={
	ok = 0,
	server_error = 1,
	nodata_error = 2,
}

-- const.room = {
-- 	service_info_output_interval = 120,   		--服务信息输出间隔(秒)
-- 	check_slave_server_interval = 20,   		--检查所有服务器的间隔
-- 	check_validity_interval = 120, 			--检查当前服务是否重复间隔
-- 	invalid_room_id = -1,				--无效的房间id
-- 	wait_pay_interval = 2,				--等待付费完成时间（秒）
-- 	check_bind_interval = 2,			--匹配房间与娃娃机间隔（秒）
-- 	check_wawaji_interval = 10,			--检查娃娃机间隔（秒）
-- 	wawaji_heartbeat_timeout = 20,		--娃娃机心跳超时（秒）
-- 	check_play_end = 1,				--检查一局游戏是否已经结束（秒）
-- 	wait_wawaji_report_result = 15,		--等待wawaji上报结果的时间（秒）
-- 	bgsave_interval = 10,				--定时保存的时间间隔（秒）
-- 	check_play_interval = 1,			--房间玩法循环（秒）
-- 	preserve_interval = 5,				--房间保留给某个用户的时间（秒）
-- 	user_in_room = 1,				--用户进房间
-- 	user_out_room = 2,				--用户出房间
-- 	max_room_user_list_len = 5,			--返回房间用户列表最大长度

-- 	check_machine_bind_interval = 2,		--匹配房间与game machine间隔（秒）
-- 	check_machine_interval = 10,			--检查game machine间隔（秒）
-- 	machine_heartbeat_timeout = 20,		--game machine心跳超时（秒）
-- }

const.machine_pos = {
	expire = 180,			--seconds
	update_interval = 90,		--seconds	
}

const.room_bgsave_fields = {
	running_status = true,
	user_cnt = true,
	now_wawaji_id = true,
	wawaji_stream_id1 = true,
	wawaji_stream_id2 = true,
	user_stream_id = true,
}

--房间管理状态（用于后台配置）
const.room_mgr_status = {
	avaible = 0,					--可用
	maintain = 1,					--维护
	gm = 2,						--gm（即还未avaible，需要上架前检查）
}

--房间运行状态（用于服务器实际标记）
const.room_running_status = {
	initing = 0,					--初始化中
	idle = 1,					--空闲
	gaming = 2,					--游戏中
	maintaining = 3,			--维护中
	gm = 4, 					--gm状态，用于上架前检查
}

const.room_type = {
	invalid = -1,					--无效
	fix_price = 1,					--固定价格
	practice = 2,					--练习			
}

const.room_idip_error_code = {
	ok = 0,
	not_master = 1,					--当前不是master
	room_already_exists = 2,			--房间已经存在
	start_room_fail = 3,				--启动房间失败
	room_not_exists = 4,				--房间不存在
	call_room_fail = 5,				--调用房间失败
	room_is_gaming = 6,				--房间仍然在游戏中
	server_error = 7,				--服务器错误
}

const.excharge_apple_bundle_id = "com.lkgame.superclaw"

-- 支付
const.excharge_errcode = {
	ok = 0,
	not_open = 1,				-- 不开放充值
	gen_order_fail = 2,			-- 生成订单失败
	invalid_arg = 3,			-- 参数错误
	http_request_error = 4,		-- 请求失败, 连接不到支付服务器
	http_status_error = 5,		-- 请求失败, 状态码不等于200
	http_data_error = 6,		-- 请求失败, 返回数据解析失败
	pay_status_error = 7,		-- 支付失败，状态码不等于0
	pay_data_error = 8,			-- 支付失败，返回数据解析失败
	server_error = 9,			-- 服务器错误
	order_not_found = 10,		-- 找不到该订单
	order_closed = 11,			-- 订单已关闭，较早前已处理完成
	order_invalid = 12,			-- 订单无效
	pubkey_invalid = 13,		-- 支付公钥无效
	pay_sign_error = 14,		-- 支付失败，返回签名无效
	server_cfg_error = 15,		-- 服务器配表错误
	old_order = 16,				-- 交易已在较早前的订单完成
	order_timeout = 17,			-- 交易超时
}

const.excharge_apple_bundle_id = "fishing.free.bu.yu"

const.excharge_result = {
	create =  0,
	finish = 1,
}

const.excharge_plat = {
	apple = 1,
	wc = 2,
	ali = 3,
}

const.excharge_plat_name = {
	[const.excharge_plat.apple] = "apple",
	[const.excharge_plat.wc] = "wc",
	[const.excharge_plat.ali] = "ali",
}

const.excharge_status = {
	default = -1,
	ok = 0,
}

const.excharge_product = {
	default = 0,          -- 默认直充钻石;
}

const.user_info_change = {
	update_diamond = 1,
	update_gold = 2,
	update_level = 3,
	update_exp = 4,
}

const.player_limit = {
	default = 999999999999,	--玩家身上各种财产的上限
	diamond = 0x7fffffff,	--钻石上限
}

const.mail_error_code = {
	ok = 0,
	not_exists = 1,
	expired = 2,
	invalid_args = 3,
	server_error = 4,
	backpack_full = 5,
	mail_sended = 6,
}

const.mailsender_error_code = {
	ok = 0,
	mailbox_full = 1,
	args_error = 2,
	server_error = 3,
}

const.sys_mail_type = {
	backpack_full = 1,
}

const.mail_const = {
	sys_mail_count = 30,		-- 邮件个数
	sys_mail_ex_time = 604800,	-- 邮件过期时间
	allow_expired_count = 10,	-- 允许过期邮件数目, 过多则mailsender进行清理
}

do
local sys_mail_type = const.sys_mail_type
const.mail_type_2_tlog = {
	[sys_mail_type.backpack_full] = "backpack_full_mail",
}
end

const.money_type = {
	gold            = 0,
	diamond         = 1,
}

--fct: flow change type
const.fct = {
	add = 0,
	reduce = 1,
}

--mfr: money flow reason
--用户财富原因
const.mfr = {
	none = 0,
	gm_operation = 1,
	charge = 2,	
	begin_play = 3,									--抓娃娃扣费
	play_fail_inc_back = 4,								--开始游戏失败，补回扣费
	backpack_full_mail = 5,							-- 背包满邮件
	invalid = 65535,								--无效

}

--pfr: prop flow reason
--用户道具流水原因
const.pfr = {
	none = 0,
	gm_operation = 1,
	backpack_full = 2,								-- 背包满
	backpack_full_mail = 3,							-- 背包满邮件

	invalid = 65535,								--无效
}

const.wawaji = {
	reg_self_interval = 5,			--每n秒向room_master注册自己
	invalid_wawaji_id = -1,			--无效的wawaji_id
}

const.wawaji_handle = {
	up = 1,					--上    	
	down = 2,				--下
	left = 3,					--左
	right = 4,				--右
	grab = 5,				--抓
}

local valid_wawaji_handle = {}
for k, v in pairs(const.wawaji_handle) do
	valid_wawaji_handle[v] = true
end
const.valid_wawaji_handle = valid_wawaji_handle

--抓娃娃结果
const.wawaji_result = {
	success = 1,					--下抓成功	
	fail = 2,						--下抓失败
	timeout = 3,					--玩家,超时失败
	wawaji_no_result = 4,				--娃娃机故障，没有上报结果
}


const.mytestmachine = {
	reg_self_interval = 5,			--每n秒向room_master注册自己
	invalid_machine_id = -1,			--无效的machine_id
}

const.sms = {
	expire = 600,                   -- 10 minute
	verify_code_b = 12345,			-- 验证码开始
	verify_code_e = 12345, 			-- 验证码
	reg = 0,						-- 注册
	modify = 1, 					-- 修改密码
	template_code = "SMS_64090037", -- 
	verify_times_limits = 3, 		-- 验证码校验限制次数
}

const.sms_error_code = {
	ok = 0,
	invalid_phone_number = 1,             
	server_error = 2,                    --服务器错误
	bussiness_limit = 3,            --alidayu bussiness limit, 阿里大于逻辑限制(发送过于频繁)
	error_response = 4,             --decode response,got 'error_response', 服务器错误
	already_used = 5,               --手机已经被使用	
	invalid_param = 6, 				--参数错误
	phone_not_exsit = 7,			-- 未绑定手机
	beyond_verify_limit = 8, 		-- 超出校验限制次数
	req_too_fast = 9, 				-- 请求太频繁
	wrong_verify_code= 10, 			-- 验证号错误 
}

const.friend_rel_type = {
	game = 1,
	external = 2,
}

const.friend_error_code = {
	ok = 0,
	invalid_args = 1,
	user_not_exists = 2,
	already_friend = 3,
	fri_req_sended = 4,
	server_error = 5,
	req_not_exists = 6,
	already_send = 7,
	friend_n_limit = 8,
	target_friend_n_limit = 9,
	target_fri_req_n_limit = 10,
}

const.friend_const = {
	fri_req_ex_time = 604800,
	fri_req_own_n = 20,
	max_friend_count = 100,
}

-- 支付宝回调时的公钥
const.recharge_alipay_pubkey = [[
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDDI6d306Q8fIfCOaTXyiUeJHkr
IvYISRcc73s3vF1ZT7XN8RNPwJxo8pWaJMmvyTn9N4HQ632qJBVHf8sxHi/fEsra
prwCtzvzQETrNRwVxLO5jVmRGi60j8Ue1efIlzPXV9je9mkjzOmdssymZkh2QhUr
CmZYI/FCEa3/cNMW0QIDAQAB
-----END PUBLIC KEY-----
]]

-- 支付宝支付时私钥
const.recharge_alipay_prikey = [[
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQCW53HlOBsWjI2YA7R3uAanXQpr4groSs1Ypnu7VOdgpQPX39K9
t5gNg6njoMJHkZZUUxq9yGHpU9VKA/cEAcCeLdhOwdP6Xl9k24pYnngCrSFOrJQc
0TJtMU6GrAIw7MH6gEld+yiOZG7osNBsDycMBYxkZCun65hHur7yewHs1wIDAQAB
AoGAA2RGUhGVwkb8c7s5litDswVLU6tr9VahEOoFA+vfm3N6B6MXOH5k44DfE6es
VjF2gISxqCxVzwm8VIKMTcHAU4T8a8CgYHQ54u+hrSiy3knTZueqg1NhGpEk+UgI
dtxyYuTFT2+Sx6aDLq9DNOPR4u3GecO9ShlNiOl24WrCIpkCQQDEkvxY6RCr3AAC
ePbsNjOC4FrfUjiacOeKwmqYc3xU3UjBABlU/1kt1ugymSHAy1hOl65xUGKnvbyo
CXWES1ptAkEAxIYE45gsJ/CCTZPwJJwC1dfaangd7rrtXPAkPlru1IE5dCvcZG3R
Z3WOZ/03W5sBzrINrYDAYfvf4pqSDkDZ0wJBALiub68IqMUOGGQ6SaJ6+cJIDpgp
o0xWLvNK3OMF/RWuIKBS+3nDvYE3m0eOXwvG/9w23YlQQJ/fvtMQr/vu37ECQDLa
t2Mp2qtPKnjmwmrG0FkD7WpFwQEo8AlvvwE/yLPG6NYuD28Rl/Gc0wgH145l8zbI
jo+KVL5GTm42L3tuvq8CQHycv0RhqX4Ru6v6f0OcrCTBw25XxXb58qA4AcDatgW9
R31uts3OJOFKJtcvstLbXuaZIXtasHFRqDIbsgJ501o=
-----END RSA PRIVATE KEY-----
]]

const.idip_config = {
	lock_expire = 5,            -- redis锁有效期，单位秒
	lock_expire_g = 20,         -- redis锁有效期，单位秒(用于GIDIP)
	lock_check_interval = 1,    -- 重取redis锁间隔，单位百分之一秒
	lock_check_times = 300,     -- 重取redis锁次数
	lock_expire_ban = 60,		-- idip事务锁有效期
	lock_expire_tip = i18[23], 	-- idip事务锁禁止登陆提示
}

const.idip = {
	max_list_size = 1000,
}

const.mysql_test_error_code={
	mysql_test_ok = 0,
	mysql_test_error = 1,
}

const.game_mode = {
	local_play = 0,		--本地一个或者组网比赛
	net_single = 1,		--一个人游戏
	net_rank = 2,		--网络排名赛
	net_team = 3,		--网络组队
}

--游戏状态
const.game_state = {
	logout= 0,
	login = 1,
	select_mode = 2,
	matching = 3,
	matchok = 4,
	roomok = 5,
	play = 6,
	over = 7,
}

const.room_state = 
{
	matching = 3,
	matchok = 4,
	roomok = 5,
	play = 6,
	over = 7,
}

const.basket_state_t =
{
	login_t = 50,			--登录时间
	matching_t = 50,		--匹配时间
	createroom_t = 20,		--创建房间的最小时间
	over_t = 60,			--退出时间
}

--各种超时时间
const.basket_timeout = 
{
	iot_out_t = 10,			--一个卡位的链接超时时间
	iot_heartbeat_t = 15,	--检测心跳包的时间间隔
	fd_out_t = 30,			--与一个fd的超时
}

const.room =
{
	max_player = 8,					--房间最大人数
	check_play_interval = 1,		--房间玩法循环（秒）
}

return const
