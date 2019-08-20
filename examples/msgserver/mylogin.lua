local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"
local server_list = {}
local login_users = {}

local server = {
    host = "127.0.0.1",
    port = 8600,
    multilogin = false, -- disallow multilogin
    name = "login_master",
}

function server.auth_handler(token)
    -- the token is base64(user)@base64(server):base64(password)
    local user, server, password = token:match("([^@]+)@([^:]+):(.+)")--通过正则表达式，解析出各个参数
    user = crypt.base64decode(user)
    server = crypt.base64decode(server)
    password = crypt.base64decode(password)
    skynet.error(string.format("%s@%s:%s", user, server, password))
    assert(password == "password", "Invalid password")
    return server, user
end

function server.login_handler(server, uid, secret)
    local msgserver = assert(server_list[server], "unknow server")
    skynet.error(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
    local last = login_users[uid]
    if  last then --判断是否登录，如果已经登录了，那就退出之前的登录
        skynet.call(last.address, "lua", "kick", uid, last.subid)
    end

    local id = skynet.call(msgserver, "lua", "login", uid, secret) --将uid以及secret发送给登陆点，让它做好准备，并且返回一个subid
    login_users[uid] = { address=msgserver, subid=id}
    return id
end

local CMD = {}

function CMD.register_gate(server, address)
    skynet.error("cmd register_gate")
    server_list[server] = address
end

function CMD.logout(uid, subid) --专门用来处理登出的数据清除，用户信息保存等
    local u = login_users[uid]
    if u then
        print(string.format("%s@%s is logout", uid, u.server))
        login_users[uid] = nil
    end
end

function server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(server) --服务启动需要参数