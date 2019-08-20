require "functions"
require "table_util"
local skynet = require "skynet"
local json = require "json"
local assert_util = require "assert_util"
local logger = require "logger"

local Scheduler = class("Scheduler")

function Scheduler:ctor()
	self.schedulers = {}
end

function Scheduler:schedule(callback, interval, loop, args)
	assert_util.assert_stack_trace(callback, "callback is nil")
	local id = #self.schedulers + 1
	args = args or {}
	table.insert(self.schedulers, {callback=callback, t=skynet.time()+interval, interval=interval, 
		loop=(loop or 1), args = args})
	return id
end

function Scheduler:unschedule(id)
	if not id then return end
	if not self.schedulers[id] then
		logger.err("scheduler:"..id.." not exist!")
		return
	end
	self.schedulers[id] = nil
end

function Scheduler:update(dt)
	local time_up_keys = {}
	local time = skynet.time()
	if not self.schedulers then
		table.printT(self)
	end
	for k, v in pairs(self.schedulers) do
		if time >= v.t then
			table.insert(time_up_keys, k)
		end
	end
	for _,k in ipairs(time_up_keys) do
		local v = self.schedulers[k]
		local ok,err = pcall(v.callback, self, v.args)
		if not ok then
			print(v.callback)
			skynet.error(string.format("Scheduler:update call scheduler error: %s ", err))
		end
		assert_util.assert_stack_trace(ok)

		local is_remove = false;
		if v.loop ~= -1 then
			v.loop = v.loop - 1
			if(v.loop <= 0) then
				self.schedulers[k] = nil
				is_remove = true;
			end
		end

		if not is_remove then 
			v.t = time+v.interval 
		end
	end
end

return Scheduler