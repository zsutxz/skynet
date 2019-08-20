local skynet = require "skynet"
--local divided_conf = require "divided_conf"
local libsql_split = require "libsql_split"

--加载ｄｂ分表配置
skynet.start(function()
    -- libsql_split.load_divide_conf(divided_conf)
    -- libsql_split.travel_divide_conf(divided_conf)
	-- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
