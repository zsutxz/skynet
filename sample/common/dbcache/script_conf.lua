local script_conf = {}

--通配del
script_conf.dels = "local keys = redis.call('keys',KEYS[1]); for k,key in pairs(keys) do redis.call('del',key) end; return 'OK';"
--通配hgetall
script_conf.hgetalls = "local fields = {}; local keys = redis.call('keys',KEYS[1]); for k,key in pairs(keys) do fields[#fields+1] = redis.call('hgetall',key) end; return fields;"
--通配expire
script_conf.expires = "local fields = {}; local keys = redis.call('keys',KEYS[1]); for k,key in pairs(keys) do fields[#fields+1] = redis.call('EXPIRE',key, ARGV[1]) end; return 'OK';"

return script_conf


