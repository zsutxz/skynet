local mysql = require "mysql"
local skynet = require "skynet"
local skynet_util = require "skynet_util"
local list = require "list"

local _M = setmetatable({}, {__index = mysql})

function _M.connect(opts)
	local self = mysql.connect(opts)
	self._req_cnt = 0
	self._last_resp_t = 0
	_M.set_query_mode(self, opts.queue)
	return self
end

local function handle_resp(self, co, ok, ...)
	self._req_cnt = self._req_cnt - 1
	self._last_resp_t = skynet.now()
	if co and self._queue and self._queue:left() == co then
		self._queue:pop()
		if not self._queue:empty() then
			skynet.wakeup(self._queue:left())
		end
	end
	if not ok then error(...) end
	return ...
end

local function reconnect(self)
	local channel = self.sockchannel
	channel:close()
	channel:connect(true)
end

local function check_timeout(self)
	while true do
		if self._req_cnt > 0 and skynet.now() - self._last_resp_t > 6000 then
			skynet.error("mysql timeout")
			self._last_resp_t = skynet.now()
			xpcall(reconnect, skynet_util.handle_err, self)
		end
		skynet.sleep(3000)
	end
end

local function en_queue(self, co)
	local queue = self._queue
	local qlen = queue and queue:len() or 0
	if qlen > 0 then
		queue:push(co)
		if qlen >= self._queue_threshold then
			skynet.error(string.format("Mysql query may overload, queue length = %d", qlen+1))
			self._queue_threshold = self._queue_threshold * 2
		end
		skynet.wait(co)
	else
		if not queue then
			queue = list.new()
			self._queue = queue
		end
		-- reset _queue_threshold when queue is empty
		self._queue_threshold = 1024
		queue:push(co)
	end
end

local function do_query(self, query, co)
	self._req_cnt = self._req_cnt + 1
	if self._req_cnt == 1 then
		self._last_resp_t = skynet.now()
		if not self._check_timeout then
			self._check_timeout = true
			skynet.fork(check_timeout, self)
		end
	end
	return handle_resp(self, co, xpcall(mysql.query, skynet_util.handle_err, self, query))
end

function _M.query(self, query)
	return do_query(self, query)
end

function _M.queue_query(self, query)
	local co = coroutine.running()
	en_queue(self, co)
	return do_query(self, query, co)
end

function _M.auto_check_query(self, query)
	if self._is_queue_enable() then
		return _M.queue_query(self, query)
	else
		return _M.query(self, query)
	end
end

function _M.set_query_mode(self, queue)
	if queue then
		if type(queue) == "function" then
			self._is_queue_enable = queue
			self.query = _M.auto_check_query
		else
			self.query = _M.queue_query
		end
	else
		self.query = _M.query
	end	
end

return _M
