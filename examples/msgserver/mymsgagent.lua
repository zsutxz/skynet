local skynet = require "skynet"

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
}

local gate
local userid, subid

local CMD = {}

function CMD.login(source, uid, sid, secret) --登录成功，secret可以用来加解密数据
    -- you may use secret to make a encrypted data stream
    skynet.error(string.format("%s is login", uid))
    gate = source
    userid = uid
    subid = sid
    -- you may load user data from database
end

local function logout() --退出登录，需要通知gate来关闭连接
    if gate then
        skynet.call(gate, "lua", "logout", userid, subid)
    end
    skynet.exit()
end

function CMD.logout(source)
    -- NOTICE: The logout MAY be reentry
    skynet.error(string.format("%s is logout", userid))
    logout()
end

function CMD.disconnect(source) --gate发现client的连接断开了，会发disconnect消息过来这里不要登出
    -- the connection is broken, but the user may back
    skynet.error(string.format("disconnect"))
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(source, ...)))
    end)

    skynet.dispatch("client", function(_,_, msg)
        skynet.error("recv:", msg)
        skynet.ret(string.upper(msg))
        if(msg == "quit")then --一旦收到的消息是quit就退出当前服务，并且关闭连接
            logout()
        end
    end)
end)