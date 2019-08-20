local skynet = require "skynet"
local logger = require "logger"
local cache_util = require "cache_util"
local sqlutil = require "sqlutil"
local profile = require "profile"
local query_sharedata = require "query_sharedata"
local trans = require "trans"
local cjson = require "cjson"
local game_option = require "game_option"
local const = require "const".mail
local uuid = require "uuid"

local COM_MAIL_TYPE = const.COM_MAIL_TYPE

require "table_util"
require "skynet.manager"

local CMD = {}

--profile stat
local profile_stat= {} -- <cmd, (invoke count, total time, max time) >

skynet.init(function ()
	-- body
end)

-- 普通邮件则作为领取中心, 可放一些道具,金币等信息
local function encode_common_mail_content(cont)
	if not cont.msg then
		local context = {
			title = cont.msg.title or "no title",
			msg = cont.msg.msg or "no msg"
		}
		cont.msg = context
	end
	local ret = cjson.encode(cont)
	return ret
end

local function notice_new_com_mail(uid, mail)
	local isol = skynet.call(".users_manager", "lua", "isOnline", uid)
	if not isol then
		-- offline
		return
	else
		-- online
		skynet.call(trans.uid_agent(uid), "lua", "call_sink", "mail", "new_com_mail", mail.guid)
	end
end

-- 普通邮件
-- m_flag = {type=const.mail.COM_MAIL_TYPE.DEFAULT,automail=const.mail.COM_AUTO_MAIL,gameid=0}
local function create_com_mail(uid, content, m_flag)
	if not uid then
		logger.err("create_com_mail param err. not uid ")
	end
	local create_date = os.time()
	local expire_date = create_date + 3600*24*7
	local mailguid = uuid()
    local mail = {
        guid = mailguid,
        uid = uid,
        type = m_flag.type or 0,
        content = content,
        gameid = m_flag.gameid,
        automail = m_flag.automail,
        createtime = create_date,
        expiretime = expire_date
    }
	local res = cache_util.call("db_player", "create_com_mail", mail)

	if res and res.affected_rows == 1 then
        --处理gameid为0和本游戏的com_mail
        if m_flag.gameid == 0 or m_flag.gameid == game_option.game_config.game_id then
            notice_new_com_mail(uid, mail)
        end
	end
end

--[[
content = {
	msg = {
		title = string
		msg = string
	},
	items =  {{itemid = xx, itemcount = xx}, {...}},
	game_coin = integer,
	game_kcoin = integer,
	crystal = integer,
}
m_flag = {
    type = const.mail.COM_MAIL_TYPE
    automail = const.mail.AUTO_MAIL
    gameid = 0  指定邮件能领取的服务器类型
}
]]
function CMD.create_com_mail(uid, content, m_flag)
    --default mail 
    m_flag = m_flag or {}
    m_flag.automail = m_flag.automail or const.COM_AUTO_MAIL.DEFAULT
    m_flag.type = m_flag.type or COM_MAIL_TYPE.DEFAULT
    m_flag.gameid = m_flag.gameid or 0        --0表示所有游戏都可以领取

	if type(content) ~= "table" then
		logger.err("create_com_mail content must be a table")
		return false
	end
	local c = encode_common_mail_content(content)
	create_com_mail(uid, c, m_flag)
	return true
end

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = CMD[cmd]
		if f then
            profile.start()

            skynet.ret(skynet.pack(f(...)))

            local time = profile.stop()
            local p = profile_stat[cmd]
            if p == nil then
              p = {n = 0, time = 0, peak = 0}
              profile_stat[cmd] = p
            end

            p.n = p.n + 1
            p.time = p.time + time
            p.peak = (p.peak < time) and time or p.peak

        else
            error(string.format('Unkown command "%s"', tostring(cmd)))
        end
	end)
	skynet.register("mailsender")
end)
