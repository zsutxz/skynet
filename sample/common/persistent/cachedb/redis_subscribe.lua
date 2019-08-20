local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local redis = require "redis"
local logger = require "logger"
local cjson = require "cjson"
local trans = require "trans"

local psub_redis_host = skynet.getenv('psub_redis_host') or ''
local psub_redis_port = skynet.getenv('psub_redis_port') or 0

local conf = {
    host = psub_redis_host,
    port = psub_redis_port,
    db = 0,
}

local function IsAgentExists(userid)
    return skynet.localname(trans.uid_agent(userid)) and true or false 
end

local function handle_subscribe_channel_msg(channel, msg)
    logger.debug("subscribe recv [%s] msg:%s",channel,msg)

    if channel == 'new_com_mail' then
        --收到新邮件通知
        local ok ,new_mail = pcall(cjson.decode, msg) 
        if not ok then
            logger.err('handle subscribe msg cjson decode err, channel:%s, msg:%s', channel, msg)
            return
        end

        if new_mail.type == 1 then 
            --通知所有用户
        elseif new_mail.type == 0 and new_mail.uid then           
            if IsAgentExists(new_mail.uid) then 
                skynet.send(trans.uid_agent(new_mail.uid), 'lua', "call_sink", "mail", "new_com_mail", new_mail.guid)
            end
        end
    end
end

--publish用的redis连接
local pub_redis = nil

local request_cmd = {}
function request_cmd.subscribe(channel)
    local function watching(channel)
        local w = redis.watch(conf)
        w:subscribe(channel)
        while true do
            local msg = w:message()

            handle_subscribe_channel_msg(channel, msg)
        end
        logger.info("leave subscribe channel:",channel)
    end

    if not channel or #channel == 0 then
        logger.err("subscribe channel, channel err:%s",tostring(channel))
        return false
    end
    logger.info('subscribe channel:%s',channel)

    skynet.fork(watching, channel)
    return true
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = request_cmd[cmd]
		if f then
            if session ~= 0 then
                skynet.ret(skynet.pack(f(...)))
            else
                f(...)
            end
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)

    skynet.register ".redis_subscribe"
end)

