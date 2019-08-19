package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;test/?.lua"

local crypt = require "crypt"
local socket = require "clientsocket"

if _VERSION ~= "Lua 5.3" then
    error "Use lua 5.3"
end

local fd = assert(socket.connect("127.0.0.1", 8600))

local function writeline(fd, text)
    socket.send(fd, text .. "\n")
end

local function unpack_line(text)
    local from = text:find("\n", 1, true)
    if from then
        return text:sub(1, from-1), text:sub(from+1)
    end
    return nil, text
end

local last = ""

local function unpack_f(f)
    local function try_recv(fd, last)
        local result
        result, last = f(last)
        if result then
            return result, last
        end
        local r = socket.recv(fd)
        if not r then
            return nil, last
        end
        if r == "" then
            error "Server closed"
        end
        return f(last .. r)
    end

    return function()
        while true do
            local result
            result, last = try_recv(fd, last)
            if result then
                return result
            end
            socket.usleep(100)
        end
    end
end

local readline = unpack_f(unpack_line)

local challenge = crypt.base64decode(readline()) --接收challenge

local clientkey = crypt.randomkey()

print("clientkey is ", clientkey)

--把clientkey换算后比如称它为ckeys，发给服务器
writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey))) 
local secret = crypt.dhsecret(crypt.base64decode(readline()), clientkey) 

print("sceret is ", crypt.hexencode(secret)) --secret一般是8字节数据流，需要转换成16字节的hex字符串来显示。

local hmac = crypt.hmac64(challenge, secret) --加密的时候需要直接传递secret字节流
writeline(fd, crypt.base64encode(hmac))

local token = {
    server = "sample",
    user = "nzhsoft",
    pass = "password",
}

local function encode_token(token)
    return string.format("%s@%s:%s",
        crypt.base64encode(token.user),
        crypt.base64encode(token.server),
        crypt.base64encode(token.pass))
end

local etoken = crypt.desencode(secret, encode_token(token)) --使用DES加密token得到etoken, etoken是字节流
writeline(fd, crypt.base64encode(etoken)) --发送etoken，mylogin.lua将会调用auth_handler回调函数, 以及login_handler回调函数。

local result = readline() --读取最终的返回结果。
print(result)
local code = tonumber(string.sub(result, 1, 3))
assert(code == 200)
socket.close(fd)    --可以关闭链接了

local subid = crypt.base64decode(string.sub(result, 5)) --解析出subid

print("login ok, subid=", subid)

local function send_request(v, session) --打包数据v以及session
    local size = #v + 4
    -->I2大端序2字节unsigned int，>I4大端序4字节unsigned int
    local package = string.pack(">I2", size)..v..string.pack(">I4", session)
    socket.send(fd, package)
    return v, session
end

local function recv_response(v)--解包数据v得到content（内容）、ok（是否成功）、session（会话序号）
    local size = #v - 5
    --cn：n字节字符串 ; B>I4: B unsigned char，>I4，大端序4字节unsigned int
    local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
    return ok ~=0 , content, session
end

local function unpack_package(text)--读取两字节数据长度的包
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s+2 then
        return nil, text
    end

    return text:sub(3,2+s), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)    -->大端序，s计算字符串长度，2字节整形表示
    socket.send(fd, package)
end

local text = "echo"
local index = 1

print("connect")
fd = assert(socket.connect("127.0.0.1", 8601 )) --连接消息服务器对应的ip端口
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index) --index用于断链恢复
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret) --加密握手hash值得到hmac，保证handshake数据接收无误，没被篡改。
send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))  --发送handshake


print(readpackage()) --接收应答
print("===>",send_request(text,0)) --发送两次
print("===>",send_request(text,1))
print("<===",recv_response(readpackage())) --不管是否已经接受了
print("<===",recv_response(readpackage()))
print("disconnect")
socket.close(fd)

print("connect")
fd = assert(socket.connect("127.0.0.1", 8601))
last = ""
index = index + 1
handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())
-- print("===>",send_request("fake",0))    -- request again (use last session 0, so the request message is fake)
-- print("===>",send_request("again",2))   -- request again (use new session)
-- print("<===",recv_response(readpackage()))
-- print("<===",recv_response(readpackage()))
local session = 0
while(true) do
    text = socket.readstdin() --循环读取标准数据发送给服务器
    if text then
        print("===>",send_request(text,session))
        print("<===",recv_response(readpackage()))
        session = session + 1 --会话ID自动递增
    end
    socket.usleep(100)
end

print("disconnect")
socket.close(fd)