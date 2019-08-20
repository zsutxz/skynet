local skynet = require "skynet"
local sharedata = require "sharedata"

local data_pool = {}
local query_queue = {}

local function query_sharedata(name)
	if data_pool[name] then return data_pool[name] end
	if not query_queue[name] then
		query_queue[name] = {}
		data_pool[name] = sharedata.query(name)
		local tmp_queue = query_queue[name]
		query_queue[name] = nil
		for k,v in ipairs(tmp_queue) do skynet.wakeup(v) end
	else
		table.insert(query_queue[name], (coroutine.running()))
		skynet.wait()		
	end
	return data_pool[name]
end

return query_sharedata
