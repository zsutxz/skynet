local logger = require "logger"
local futil = require "futil"
local skynet = require "skynet"
local mysql = require "mysql"

local sqlutil = {}

--return true for no error, false for some error
function sqlutil.checkMySqlErr(res, sql, ingored_errno)
    if not res then
    	skynet.error(string.format("sql error, res nil, sql = [[%s]]", sql))
        return false
    end

    if res.badresult == true and res.errno ~= ingored_errno then
        skynet.error(string.format("sql error, res = %s, sql = [[%s]]", futil.toStr(res), sql))
        return false
    end

    return true
end

function sqlutil.make_where_and(where)
	if type(where) == "string" then
		return where
	end
	local wt = {}
	for k, v in pairs(where) do
		local qv = type(v) == "string" and mysql.quote_sql_str(v) or v
		local s = string.format("%s=%s", k, qv)
		table.insert(wt, s)
	end
	local ws = table.concat(wt, " and ")
	return ws
end

function sqlutil.quote_if_string(s)
	return type(s) == "string" and mysql.quote_sql_str(s) or s
end

return sqlutil
