local crypt = require "crypt"

--[[
	插入元素到 sorted set 队头
	KEYS[1] = sorted set queue key
	ARGV[1] = enqueue element
	ARGV[2] = hint score
]]
local lenqu =
[[local f=redis.call
local k,e,c=KEYS[1],ARGV[1],tonumber(ARGV[2]) or 0
local r=f('zrange',k,0,0,'withscores')
local rc=tonumber(r[2])
if rc and rc <= c then c = rc-1 end
f('zadd',k,c,e)
return {f('zcard',k), c}]]

--[[
	插入元素到 sorted set 队尾
	KEYS[1] = sorted set queue key
	ARGV[1] = enqueue element
	ARGV[2] = hint score
]]
local renqu =
[[local f=redis.call
local k,e,c=KEYS[1],ARGV[1],tonumber(ARGV[2]) or 0
local r=f('zrange',k,-1,-1,'withscores')
local rc=tonumber(r[2])
if rc and rc >= c then c = rc+1 end
f('zadd',k,c,e)
return {f('zcard',k), c}]]

--[[
	同时获取 sorted set 的 rank,score,card
	KEYS[1] = sorted set key
	ARGV[1] = element key
]]
local zrsc = 
[[local f,k,e=redis.call,KEYS[1],ARGV[1] return {f('zrank',k,e),f('zscore',k,e),f('zcard',k)}]]

--[[
	同时获取 sorted set 的 revrank,score,card
	KEYS[1] = sorted set key
	ARGV[1] = element key
]]
local zrrsc = 
[[local f,k,e=redis.call,KEYS[1],ARGV[1] return {f('zrevrank',k,e),f('zscore',k,e),f('zcard',k)}]]

--[[
	更新key值，当且仅当key未设置或为指定的旧值
	KEYS[1]	= string key
	ARGV[1] = new key value
	ARGV[2] = old key value
]]
local setk = 
[[local r=redis.call('get',KEYS[1]) if not r or r==ARGV[2] then redis.call('set',KEYS[1],ARGV[1]) return ARGV[1] end return r]]

--[[
	删除用户所在服务器位置
	KEYS[1] 用户位置key
	ARGV[1] 服务器名	
]]
local delete_pos_by_openid = "local r=redis.call('get',KEYS[1]) if r==ARGV[1] then redis.call('del',KEYS[1]) end"

--[[
	更新用户所在服务器位置
	KEYS[1] 用户位置key
	ARGV[1] 服务器名	
	ARGV[2] 失效时间
]]
local update_pos_by_openid = 
[[local r=redis.call('get',KEYS[1]) 
if not r then 
	redis.call('setex',KEYS[1], ARGV[1], ARGV[2]) 
	return 'OK' 
elseif r==ARGV[2] then 
	redis.call('expire',KEYS[1], ARGV[1]) 
	return 'OK' 
else
	return {'NO', r}
end]]


--[[
	删除wawaji所在服务器位置
	KEYS[1] wawaji位置key
	ARGV[1] 服务器名	
]]
local delete_pos_by_wawaji_id = "local r=redis.call('get',KEYS[1]) if r==ARGV[1] then redis.call('del',KEYS[1]) end"

--[[
	更新wawaji所在服务器位置
	KEYS[1] wawaji位置key
	ARGV[1] 服务器名	
	ARGV[2] 失效时间
]]
local update_pos_by_wawaji_id = 
[[local r=redis.call('get',KEYS[1]) 
if not r then 
	redis.call('setex',KEYS[1], ARGV[1], ARGV[2]) 
	return 'OK' 
elseif r==ARGV[2] then 
	redis.call('expire',KEYS[1], ARGV[1]) 
	return 'OK' 
else
	return {'NO', r}
end]]

--[[
	删除machine所在服务器位置
	KEYS[1] machine位置key
	ARGV[1] 服务器名	
]]
local delete_pos_by_machine_id = "local r=redis.call('get',KEYS[1]) if r==ARGV[1] then redis.call('del',KEYS[1]) end"

--[[
	更新machine所在服务器位置
	KEYS[1]machine位置key
	ARGV[1] 服务器名	
	ARGV[2] 失效时间
]]
local update_pos_by_machine_id = 
[[local r=redis.call('get',KEYS[1]) 
if not r then 
	redis.call('setex',KEYS[1], ARGV[1], ARGV[2]) 
	return 'OK' 
elseif r==ARGV[2] then 
	redis.call('expire',KEYS[1], ARGV[1]) 
	return 'OK' 
else
	return {'NO', r}
end]]



--[[
	KEYS[1] = redis的key名, list类型
	ARGV[1] = 需要删除的成员数
--]]
local pop_list = [[
	local f = redis.call
	local kn = KEYS[1]
	local dc = tonumber(ARGV[1])
	local rc = 0
	for i = 1, dc do
		if not f('lpop', kn) then
			break
		end
		rc = rc + 1
	end
	return rc
]]

local refresh_lock = 
[[local r=redis.call('get',KEYS[1]) 
if r==ARGV[1] then 
	redis.call('set',KEYS[1],ARGV[1],'ex',ARGV[2] or 60)
	return 'OK' 
else 
	return {r,redis.call('ttl',KEYS[1])} 
end]]

local free_lock = 
[[local r=redis.call('get',KEYS[1]) 
if r==ARGV[1] then 
	redis.call('del',KEYS[1]) 
end]]

-- 设置idip请求锁
local test_and_get = 
[[local r=redis.call('get',KEYS[1]) 
if not r then 
	redis.call('setex',KEYS[1], ARGV[1], ARGV[2]) 
	return 'OK' 
else
	return 'NO'
end]]

-- 释放idip请求锁
local test_and_del = "local r=redis.call('get',KEYS[1]) if r==ARGV[1] then redis.call('del',KEYS[1]) end"

local incrbyx = 
[[if redis.call("exists", KEYS[1]) == 0 then
	return
end
return redis.call("incrby", KEYS[1], ARGV[1])]]

local scripts = {
	time = "return redis.call('time')",
	lenqu = lenqu,
	lenqu_sha = crypt.hexencode(crypt.sha1(lenqu)),
	renqu = renqu,
	renqu_sha = crypt.hexencode(crypt.sha1(renqu)),
	zrsc = zrsc,
	zrsc_sha = crypt.hexencode(crypt.sha1(zrsc)),
	zrrsc = zrrsc,
	zrrsc_sha = crypt.hexencode(crypt.sha1(zrrsc)),
	setk = setk,
	setk_sha = crypt.hexencode(crypt.sha1(setk)),
	delete_pos_by_openid = delete_pos_by_openid,
	delete_pos_by_openid_sha = crypt.hexencode(crypt.sha1(delete_pos_by_openid)),
	update_pos_by_openid = update_pos_by_openid,
	update_pos_by_openid_sha = crypt.hexencode(crypt.sha1(update_pos_by_openid)),
	delete_pos_by_wawaji_id = delete_pos_by_wawaji_id,
	delete_pos_by_wawaji_id_sha = crypt.hexencode(crypt.sha1(delete_pos_by_wawaji_id)),
	update_pos_by_wawaji_id = update_pos_by_wawaji_id,
	update_pos_by_wawaji_id_sha = crypt.hexencode(crypt.sha1(update_pos_by_wawaji_id)),

	delete_pos_by_machine_id = delete_pos_by_machine_id,
	delete_pos_by_machine_id_sha = crypt.hexencode(crypt.sha1(delete_pos_by_machine_id)),
	update_pos_by_machine_id = update_pos_by_machine_id,
	update_pos_by_machine_id_sha = crypt.hexencode(crypt.sha1(update_pos_by_machine_id)),

	pop_list = pop_list,
	pop_list_sha = crypt.hexencode(crypt.sha1(pop_list)),
	refresh_lock = refresh_lock,
	refresh_lock_sha = crypt.hexencode(crypt.sha1(refresh_lock)),
	free_lock = free_lock,
	free_lock_sha = crypt.hexencode(crypt.sha1(free_lock)),
	test_and_get = test_and_get,
	test_and_get_sha = crypt.hexencode(crypt.sha1(test_and_get)),
	test_and_del = test_and_del,
	test_and_del_sha = crypt.hexencode(crypt.sha1(test_and_del)),
	incrbyx = incrbyx,
	incrbyx_sha = crypt.hexencode(crypt.sha1(incrbyx)),
}

return scripts
