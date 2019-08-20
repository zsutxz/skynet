local skynet = require "skynet"

skynet.start(function()
    --启动mylogin监听8600
    local loginserver = skynet.newservice("mylogin") 
    --启动mymsgserver传递loginserver地址 
    local msgserver = skynet.newservice("mymsgserver", loginserver) 
    --网关服务需要发送lua open来打开，open也是保留的命令
    skynet.call(msgserver, "lua", "open" , { 
        port = 8601,
        maxclient = 64,
        servername = "sample",  --取名叫sample，跟使用skynet.name(".sample")一样
    })
end)