local skynet = require "skynet"
local List = require "list"

local c = {_name = ""}
c.__index = c

local function printf(fmt, ...)
	return print(string.format(fmt, ...))
end

-- note: 返回的锁中, 不能改变的字段: _lock, _waiting, _id, _t
function c:get(id)
	assert(id)
	local l = self._locks[id]
	if not l then
		l = {_lock = coroutine.running(), _id = id, _t = skynet.now()}
		self._locks[id] = l
		return l
	end
	if not l._lock then
		l._lock = coroutine.running()
		l._t = skynet.now()
		return l
	end
	local co = coroutine.running()
	if coroutine.status(l._lock) == "dead" then
		printf("lock [%s][%s] held by dead thread\n%s", tostring(self._name),
			tostring(l._id), debug.traceback(l._lock))
		if not l._waiting or l._waiting:empty() then
			l._lock = co
			l._t = skynet.now()
			return l
		end
		l._waiting:pushright(co)
		self:release(l, true)
	else
		if not l._waiting then l._waiting = List.new() end
		l._waiting:pushright(co)
	end	
	skynet.wait()
	assert(l._lock == co)
	l._t = skynet.now()
	return l
end

-- keep : 是否保留锁
function c:release(l, keep)
	if not l then return end
	if l._id == nil then
		-- multiple locks
		for _,v in ipairs(l) do
			assert(v._id ~= nil)
			self:release(v, keep)
		end
		return
	end
	assert(l._lock)
	if l._waiting and not l._waiting:empty() then
		l._lock = l._waiting:popleft()
		if l._lock ~= coroutine.running() then skynet.wakeup(l._lock) end
		return
	end
	if keep then
		l._waiting = nil
		l._lock = nil
	else
		self._locks[l._id] = nil
	end
end

function c:release_id(id)
	assert(id)
	self:release(self._locks[id])
end

-- note: 返回由 lock:get 获得的锁列表
function c:gets(ids)
	table.sort(ids, self._sort)
	local larr = {}
	for _,id in ipairs(ids) do
		table.insert(larr, self:get(id))
	end
	return larr
end

-- 检查锁是否被占用
function c:locked(id)
	return self._locks[id] and true or false
end

-- 检查并清理死锁
local function check_deadlock(self)
	while true do
		local id = next(self._locks)
		local t = skynet.now()
		while id do
			local l = self._locks[id]
			if not l then break end
			local tmp_id = next(self._locks, id)
			if l._lock then
				if coroutine.status(l._lock) == "dead" then
					printf("lock [%s][%s] held by dead thread\n%s", tostring(self._name),
						tostring(l._id), debug.traceback(l._lock))
					self:release(l, true)
				elseif skynet.now() - l._t > 6000 then
					printf("lock [%s][%s] deadlocked\n%s", tostring(self._name),
						tostring(l._id), debug.traceback(l._lock))
				end
			end
			id = tmp_id
			if skynet.now() - t > 1 then
				skynet.sleep(2)
				t = skynet.now()
			end
		end
		skynet.sleep(6000)
	end
end

function c.new(name, sort_f)
	local r = setmetatable(
		{
			_name = type(name) == "string" and name or nil,
			_locks = {},
			_sort = sort_f,
		}, c)
	skynet.fork(check_deadlock, r)
	return r
end

return c
