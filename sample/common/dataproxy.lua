local skynet = require "skynet"
local skynet_util = require "skynet_util"
local logger = require "logger"
require "skynet.manager"
local futil = require "futil"

local dataproxy = {}
local workerCnt = tonumber(skynet.getenv("dataworkercnt")) or 3
local curWorker = math.random(0, workerCnt-1)

--call调用
--success: return true, ...
--fail   : return false, error(string)
function dataproxy.call(reqname, ...)
	local wokerName = string.format(".dataworker%d", curWorker)
	curWorker = (curWorker + 1) % workerCnt
	local ret = table.pack(xpcall(skynet.call, skynet_util.handle_err, wokerName, "lua", reqname, ...))
	if not ret[1] then
		skynet.error("dataproxy.call fail: reqname = ", reqname, ", args = ", table.tostring({...}))	
	end
	return table.unpack(ret, 1, ret.n)
end


--send调用
--success: return true, ...
--fail   : return false, error(string)
function dataproxy.send(reqname, ...)
	local wokerName = string.format(".dataworker%d", curWorker)
	curWorker = (curWorker + 1) % workerCnt
	return skynet.send(wokerName, "lua", reqname, ...)
end

return dataproxy
