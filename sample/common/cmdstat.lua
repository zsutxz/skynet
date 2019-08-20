local cmdstat = {_threshold = 1, _nblk = 64}
local meta = {__index = cmdstat}

function cmdstat.new(threshold, nblk)
	return setmetatable({
		_threshold = threshold,
		_nblk = nblk,
		_total = {
			cnt = 0,		-- 调用次数
			blk =0,			-- 耗时超过阈值次数
			time = 0.0, 	-- 总耗时
			avg = 0.0,		-- 平均耗时
			peak = 0.0,		-- 耗时峰值
			rtime = 0.0,	-- 总CPU时间
			ravg = 0.0,		-- 平均CPU时间
			rpeak = 0.0,	-- CPU时间峰值
		},
		_cmds = {},
		_blks = {},		-- {ut:耗时, rt:CPU时间, cmd:请求名, from:调用方, stmp:时间戳}
		_newblk = false,
	}, meta)
end

local function doStat(stat, costTime, profileTime, blk)
	if not stat then
		stat = {
			cnt=1, time=costTime, avg=costTime, peak=costTime,
			rtime=profileTime, ravg=profileTime, rpeak=profileTime,
			blk=blk and 1 or 0,
		}
	else
		stat.cnt = stat.cnt + 1
		stat.time = stat.time + costTime
		stat.rtime = stat.rtime + profileTime
		if blk then stat.blk = stat.blk + 1 end
		stat.avg = nil
		stat.ravg = nil
		if costTime > stat.peak then stat.peak = costTime end
		if profileTime > stat.rpeak then stat.rpeak = profileTime end
	end
	return stat
end

local function fmtStat(stat, cmd)
	if not stat.avg or not stat.ravg then
		stat.avg = stat.cnt > 0 and stat.time / stat.cnt or 0
		stat.ravg = stat.cnt > 0 and stat.rtime / stat.cnt or 0
	end
	return string.format("{cnt=%d, blk=%d, time=%.3f, avg=%.3f, peak=%.3f, rtime=%.3f, ravg=%.3f, rpeak=%.3f, cmd='%s'}",
		stat.cnt, stat.blk, stat.time, stat.avg, stat.peak, stat.rtime, stat.ravg, stat.rpeak, cmd)
end

function cmdstat:stat(cmd, startTime, endTime, profileTime, from)
	local costTime = endTime - startTime
	local blk = costTime >= self._threshold
	if not profileTime then profileTime = 0 end
	doStat(self._total, costTime, profileTime, blk)
	self._cmds[cmd] = doStat(self._cmds[cmd], costTime, profileTime, blk)
	if blk then
		local pos
		local blks = self._blks
		for k, v in ipairs(blks) do
			if v.ut <= costTime then
				if #blks >= self._nblk then table.remove(blks) end
				table.insert(blks, k, {ut=costTime, rt=profileTime, cmd=cmd, from=from, stmp=os.date("%F %T")})
				pos = k
				break
			end
		end
		if not pos and #blks < self._nblk then
			table.insert(blks, {ut=costTime, rt=profileTime, cmd=cmd, from=from, stmp=os.date("%F %T")})
		end
		self._newblk = true
	end
end

function cmdstat:strStat()
	local strs = {fmtStat(self._total, 'total')}
	for k,v in pairs(self._cmds) do
		strs[#strs+1] = fmtStat(v, k)
	end
	return table.concat(strs, ",\r\n")
end

function cmdstat:strBlks()
	local strs = {}
	for k,v in ipairs(self._blks) do
		strs[#strs+1] = string.format("{stmp='%s', ut=%.3f, cmd='%s', from=%x}", v.stmp, v.ut, v.cmd, v.from or 0)
	end
	return table.concat(strs, "\r\n")
end

function cmdstat:str()
	return string.format("{stats={\r\n%s},\r\nblks={\r\n%s}}", self:strStat(), self:strBlks())
end

function cmdstat:str_newblk()
	if self._newblk then
		self._newblk = false
		return string.format("{stats={\r\n%s},\r\nblks={\r\n%s}}", self:strStat(), self:strBlks())
	end
end

return cmdstat
