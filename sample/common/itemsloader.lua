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

-- 数据库表的名称，亦作为sharedata.new的参数
local config = {
    "common_items",
    "paodekuai_items",
    -- "jinhua_items",
    --"lksparrow_items"
}

local CMD = {}

local function loadfromdb(tablename)
	local res = cache_util.call("db_item", "load_items_config", { table_name = tablename } )
	if not res then
		logger.err("load_items_config error, name:%s ", tablename)
	end
	return res
end

local function load_items_config()
	local itemsconfig = {}
	for _,v in ipairs(config) do
		local ok, res = pcall(loadfromdb, v)
		if ok and res then
            --使用道具配置
			local s = table.make_key(res, "itemid")
            for _,item_conf in pairs(s) do
                if item_conf.useitem and #item_conf.useitem~=0 then
                    item_conf.useitem = cjson.decode(item_conf.useitem)
                end
            end

			table.merge(itemsconfig, s)
			logger.debug("load %s items config success.", v)
		end
	end

	if next(itemsconfig) then
		sharedata.new("itemsconfig", itemsconfig)
		logger.debug("load itemsconfig success")
	else
		logger.debug("no itemsconfig")
	end
end

--兑换道具配置
local function load_prize_exchange_config()
	-- body
    local res = cache_util.call("db_item","load_prize_exc_config",{})
    if not res then
		logger.debug("load item_exchange_config empty")
        return
    end

    local item_exchange = table.make_key(res, "prize_id")
    --local item_exchange = res;

    if next(item_exchange) then
		sharedata.new("item_exchange", item_exchange)
		logger.debug("load item_exchange_config success")
    end
end



skynet.start(function ()
	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
	end)

	-- 加载道具配置表
	--load_items_config()

    -- 加载兑换道具配置
    --load_prize_exchange_config()

	skynet.register(".itemsloader")
end)
