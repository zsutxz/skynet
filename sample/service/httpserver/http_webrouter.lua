local skynet = require "skynet"
local logger = require "logger"
local futil = require "futil"
local url = require "http.url"
local md5 = require "md5"
local packer = require "packer"
local print_t = require "print_t"

local proxy = require "socket_proxy"

local query_sharedata = require "query_sharedata"

local req_handler = {}

local function getenv(key, default)
    local v = skynet.getenv(key)
    if not v or (type(v) == "string" and #v == 0) then
        v = default
    end
    return v
end

local function read(fd)
	return skynet.tostring(proxy.read(fd))
end

--print(s)
--local jsonstr ='{"type":"pay","mach":"1111111111111","openid":"im test","nickname":"冷眼观潮","value":"12"}'
--local jsonstr ='{"type":"login","openid":"oyecZt6Kxxvv23S347zFAYj-dygI","qrscene":"011061234100000","incharges_id":"67","value":"1"}'
--local jsonstr ='{"type":"pay","openid":"oyecZt6Kxxvv23S347zFAYj-dygI","qrscene":"0110612341000000","incharges_id":"67","value":"1"}'

function req_handler.wechat(method, header, body, query)
    --logger.info("test_notify body = %s, query = %s", body, query)
    local kind = query["type"]
    local data = query["data"]
    local retdata={}
    
    -- 通知在线玩家处理订单
    -- send_player(order_openid, "recharge_async_req", order_id)

    local wechathandler = skynet.uniqueservice "wechathandler"
    
    if data == nil then
        retdata.errcode = "100"
        retdata.errmsg = "no data"
        retdata.data = "00000" 
    else
        logger.info("wechat kind:%s,data:%s",kind,data)
        local indata = packer.unpack(data)
        
        if kind=="login" then
            retdata = skynet.call(wechathandler,"lua","WechatLogIn",indata)
        elseif kind=="logout" then
            retdata = skynet.call(wechathandler,"lua","WechatLogOut",indata)
        elseif kind=="coin_in" then
            retdata = skynet.call(wechathandler,"lua","WechatCoinIn",indata)
        elseif kind=="select_mode" then
            retdata = skynet.call(wechathandler,"lua","WechatChooseMode",indata)
        elseif kind=="matching" then
            retdata = skynet.call(wechathandler,"lua","WechatMatching",indata)
        end 
    end
    
    local retjson = packer.pack(retdata)
    --retjson = '{"errcode":"'..retdata.errcode..'","errmsg":"'..retdata.errmsg..'","data":"'..retdata.data..'"}'
    --logger.info("packer.pack retjson:%s",retjson)
    --print(retjson)
    return 200, retjson
end

local urls = {
    ["wechat"] = req_handler.wechat,
    ["/ali_notify"] = req_handler.ali_notify,
    ["/test_notify"] = req_handler.test_notify,
}

return urls
