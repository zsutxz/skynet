local uuid = require "uuid"
local json = require "cjson"
local sc = require "socketchannel"
local csplit = require "csplit"
local futil = {}

function futil.split(s, sep)
	sep = sep or " "
    if type(s) ~= "string" then
        return nil
    end
    return csplit.csplit_to_table(s, sep)
end

function futil.repl(s, params)
	if params == nil then return s end
	if type(params) ~= 'table' then
		return string.gsub(s, '{[%d]+}', params)
	end
	return string.gsub(s, '{[%d]+}', function (ss)
		local n = tonumber(ss:sub(2, -2))
		return params[n+1]
	end)
end

function futil.getNowTimeStrFmt(now)
	return os.date("%Y-%m-%d %H:%M:%S", now or os.time())
end

function futil.getNowDateStrFmt(now)
	return os.date('%Y-%m-%d', now or os.time())
end

function futil.getYesterdayTimeStrFmt(nowTime)
	local nowTab = os.date("*t", nowTime)
	nowTab.hour = 0
	nowTab.min = 0
	nowTab.sec = 0

	local todayBegin = os.time(nowTab)
	local oneDaySecCnt = 24 * 3600
	return os.date("%Y-%m-%d %H:%M:%S", todayBegin - oneDaySecCnt)
end

function futil.getTimeByDate(dateStr)
	local a = futil.split(dateStr, " ")
	local b = futil.split(a[1], "-")
	local c = futil.split(a[2], ":")
	return os.time({year=b[1], month=b[2], day=b[3], hour=c[1],min=c[2],sec=c[3]})
end

function futil.getWeekdayBeginTime(week_day, now_time)
	-- week_day：0-6，从周日到周六
	-- now_time: 该时间戳用于指定某一周
	now_time = now_time or os.time()
	local now_tab = os.date("*t", now_time)
	now_tab.hour = 0
	now_tab.min = 0
	now_tab.sec = 0
	local today_begin = os.time(now_tab)
	local today = os.date("%w", today_begin)
	local one_day_sec_cnt = 24*3600
	local day_diff = week_day - today
	local begin_time = today_begin + (day_diff)*one_day_sec_cnt
	return begin_time
end

function futil.getThisWeekBeginTime(nowTime)
--	local nowTab = os.date("*t", nowTime)
--	nowTab.hour = 0
--	nowTab.min = 0
--	nowTab.sec = 0
--	local todayBegin = os.time(nowTab)
--	local weekDay = os.date("%w", todayBegin)
--	local oneDaySecCnt = 24*3600
--	local beginTime = todayBegin - (weekDay)*oneDaySecCnt
--	return beginTime
	return futil.getWeekdayBeginTime(0, nowTime)
end

function futil.getLastWeekBeginTime(nowTime)
--	local nowTab = os.date("*t", nowTime)
--	nowTab.hour = 0
--	nowTab.min = 0
--	nowTab.sec = 0
--	local todayBegin = os.time(nowTab)
--	local weekDay = os.date("%w", todayBegin)
--	local oneDaySecCnt = 24*3600
--	local beginTime = todayBegin - (weekDay+7)*oneDaySecCnt
--	return beginTime
	local one_week_sec_cnt = 24 * 3600 * 7
	return futil.getWeekdayBeginTime(0, nowTime) - one_week_sec_cnt
end

-- 获取今日指定时间的时间戳
-- clock格式, 例子：5:10:05
-- nowTime：该时间戳用于指定某一周
function futil.getTodayTimestamp(clock, nowTime)
	local nowTab = os.date("*t", nowTime)
	local _, _, hour, min, sec = string.find(clock, "(%d+):(%d+):(%d+)")
	local timestamp = os.time {year = nowTab.year, month = nowTab.month, day = nowTab.day,
		hour = hour, min = min, sec = sec}

	return timestamp
end

function futil.uuid()
	local val = uuid()
	return val
end

function futil.toStr(t)
	if type(t) == 'table' then
		local s = "{"
		for k, v in pairs(t) do
			local temp = string.format("%s:%s,", tostring(k), futil.toStr(v))
			s = s .. temp
		end
		s = s .. "}"
		return s
	else
		return tostring(t)
	end
end

function futil.dump(t)
	print(futil.toStr(t))
end

function futil.countTb(t)
	local cnt = 0
	for _,_ in pairs(t) do
		cnt = cnt + 1
	end
	return cnt
end

-- 字符串格式化, 参数合法性由调用者保证
-- s : 要格式化的字符串
-- ... : 格式化时使用的替换参数
-- 格式化规则: 将 %% 替换为 %, 将 %n 替换成 ... 中的第 n+1 个参数, n 为 0-9 的数字
-- 返回值: 替换之后的字符串, 发生替换次数
function futil.strformat(s, ...)
	local pattern = "%%[%d%%]"

	local t = {...}
	return string.gsub(s, pattern, function (s1)
		if s1 == "%%" then
			return "%"
		else
			local p = tonumber(s1:sub(2)) + 1
			return t[p]
		end
	end)
end

-- check if endpoint is reachable
function futil.reachable(endpoint)
	if not endpoint then return end
	local host, port = string.match(endpoint, "([^:]+):(.*)$")
	local ok, c = pcall(sc.channel, {
		host = host,
		port = tonumber(port),
	})
	if not ok then return end
	local err
	ok, err = pcall(c.connect, c, true)
	if not ok then return end
	c:close()
	return true
end

function futil.kvlist2dict(r)
	local d = {}
	for k = 1, #r, 2 do d[r[k]] = r[k+1] end
	return d
end

function futil.kv2dict(keys, vals)
	local d = {}
	for i, k in ipairs(keys) do d[k] = vals[i] end
	return d
end

function futil.isTimeBeforeThisWeek(timestamp)
	if not timestamp then
		return false
	end
	local t = tonumber(timestamp)
	local thisWeekBeginTime = futil.getThisWeekBeginTime(os.time())
	return t < thisWeekBeginTime
end

-- 获取时间戳指定的当天的开始时间
function futil.getDayBeginTime(timestamp)
	timestamp = timestamp or os.time()
	local nowTab = os.date("*t", tonumber(timestamp))
	nowTab.hour = 0
	nowTab.min = 0
	nowTab.sec = 0

	local todayBegin = os.time(nowTab)
	return todayBegin
end

function futil.isSingleWeek(week_begin_time)
	local begin_time = 1420300800		-- 2015-01-04 0:0:0的时间戳,从这周算起
	local day_sec = 86400				-- 一天的秒数
	if week_begin_time < begin_time then
		return false
	end
	local sec_diff = week_begin_time - begin_time
	local isSingleWeek = (sec_diff / day_sec / 7) % 2 == 0
	return isSingleWeek
end

function futil.tointeger(num, is_ceil)
	local val = math.tointeger(num)
	if val then
		return val
	end
	val = tonumber(num)
	if not val then return end
	if is_ceil then
		return math.ceil(val)
	end
	return math.floor(val)
end

function futil.maxn(t)
    local n = #t
    local k = next(t, n)
    while k do
        if type(k) == "number" and k > n and math.tointeger(k) then n = k end
        k = next(t, k)
    end
    return n
end

function futil.gen_guid()
	local seed = {'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
	local tb = {}
	for i=1, 32 do
		table.insert(tb, seed[math.random(1,16)])
	end
	local sid = table.concat(tb)
	return string.format('%s-%s-%s-%s-%s',
		string.sub(sid, 1, 8),
		string.sub(sid, 9, 12),
		string.sub(sid, 13, 16),
		string.sub(sid, 17, 20),
		string.sub(sid, 21, 32))
end

function futil.gen_ip()
	return string.format("%s.%s.%s.%s",
		math.random(50, 255),
		math.random(50, 255),
		math.random(0, 255),
		math.random(0, 255))
end

return futil