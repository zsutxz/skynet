local msgserver = require "snax.msgserver"
local crypt = require "crypt"
local skynet = require "skynet"

local loginservice = tonumber(...) --从启动参数获取登录服务的地址
local server = {}   --一张表，里面需要实现前面提到的所有回调接口
local servername
local subid = 0
local agents = {}

function server.login_handler(uid, secret) 
    subid = subid + 1
    local username = msgserver.username(uid, subid, servername)--通过uid以及subid获得username
    skynet.error("uid",uid, "login，newusername", username)
    msgserver.login(username, secret)--正在的登录
    agent = skynet.newservice("mymsgagent")
    skynet.call(agent, "lua", "login", uid, subid, secret)
    agents[username] = agent
    return subid
end

--一般给agent调用
function server.logout_handler(uid, subid)
    local username = msgserver.username(uid, subid, servername)
    msgserver.logout(username) --登出
    skynet.call(loginservice, "lua", "logout",uid, subid) --通知一下loginservice已经退出
    agents[username] = nil
end

--一般给loginserver调用
function server.kick_handler(uid, subid)
    local username = msgserver.username(uid, subid, servername)
    local agent = agents[username]
    if agent then
        --这里使用pcall来调用skynet.call避免由于agent退出造成异常发生
        pcall(skynet.call, agent, "lua", "logout") --通知一下agent，让它退出服务。
        
    end
end

--当客户端断开了连接，这个回调函数会被调用
function server.disconnect_handler(username) 
    skynet.error(username, "disconnect")
end

--当接收到客户端的请求，跟gateserver一样需要转发这个消息给agent，不同的是msgserver还需要response返回值
--，而gateserver并不负责这些事
function server.request_handler(username, msg)
    skynet.error("recv", msg, "from", username)
    --返回值必须是字符串，所以不管之前的数据是否是字符串，都转换一遍
    return skynet.tostring(skynet.rawcall(agents[username], "client", msg)) 
end

--注册一下登录点服务，主要是考诉loginservice这个登录点
function server.register_handler(name)
    servername = name
    skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
end

msgserver.start(server) --需要配置信息，跟gateserver一样,端口、ip，外加一个登录点名称
