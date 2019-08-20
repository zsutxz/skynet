local skynet = require "skynet"
require "skynet.manager"
local sharedata = require "sharedata"
local logger = require "logger"
local mysql = require "mysql"
local cache_util = require "cache_util"
local sqlutil = require "sqlutil"
local futil = require "futil"
local cjson = require "cjson"
local query_sharedata = require "query_sharedata"
require "table_util"
local CMD = {}

--[[
该服务主要读取网站中的配置表，并用sharedata共享。
sharedata.new的名称为数据库的表名。
默认数据库为db_config
]]
local convert = {
    "initial_coin" = function (config)
        return table.make_key(config, "gid")
    end,
}
local config = {
    "initial_coin",
}

local function loadfromdb(tablename)
    local res = cache_util.call("db_webconfig", "load_web_config", {table_name = tablename})
    if not res then
        logger.err("load webconfig error, tablename: %s", tablename)
    end
    return res
end

local function loadwebconfigs()
    local webconfigs = {}
    for _, v in ipairs(config) do
        local ok, c = pcall(loadfromdb, v)
        if ok and c then
            webconfigs[v] = convert[v] and convert[v](c) or c
        end
    end
    sharedata.new("webconfigs", webconfigs)
end

function CMD.reload()
    --to do
end

skynet.start(function ()
    skynet.dispatch("lua", function(session, sorce, cmd, ...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
    
    -- 加载网站配置
    loadwebconfigs()

    skynet.register(".webconfigsloader")
end)

