local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "skynet_util"
local sharedata = require "sharedata"
local logger = require "logger"
local futil = require "futil"
require "functions"

local globalconf = {}
local command = {}

--兼容旧逻辑
local globalConfName = skynet.getenv "global_conf_file" or "global.conf"
local globalConfPath = string.format('./conf/%s', globalConfName)

local function readLinesInFile(filePath)
	local result = {}
	local f = io.open(filePath)
	if not f then 
		return result 
	end
	for line in f:lines() do
		local l = string.trim(line)
		if string.len(l) > 0 then
			result[l] = true
		end
	end
	f:close()
	return result
end

local function loadLuaStyleConf(_path)
	local f = io.open(_path)
	if not f then
		logger.info("no conf found: %s", _path)
		return
	end
	local function getenv(name) 
		return assert(os.getenv(name), 'os.getenv() failed: ' .. name) 
	end
	local code = f:read('*a')
	f:close()
	local result = {}
	if code then
		code = string.gsub(code, '%$([%w_%d]+)', getenv)
		assert(load(code,'=(load)','t',result))()
	end
	return result	
end

local function parse_freeflow_redirect(conf)
	local parse = function(list_str)
		if not list_str or list_str == "" then
			return nil
		end
		list_str = list_str:trim()
		local host_port_list = {}
		for s in string.gmatch(list_str, "[^,]+") do
			s = s:trim()
			local host, port = string.match(s, "([^:]+):(%d+)")
			local nport = tonumber(port)
			if host and port then
				local t = {
					host = host,
					port = nport,
				}
				table.insert(host_port_list, t)
			else
				logger.err("globalconf found invalid host: %s, port: %s", host, port)
			end
		end
		return host_port_list
	end
	conf.freeflow_lt_list = parse(conf.freeflow_lt_list)
	conf.freeflow_yd_list = parse(conf.freeflow_yd_list)
	conf.freeflow_dx_list = parse(conf.freeflow_dx_list)
end

local function loadconf()
	local ret = loadLuaStyleConf(globalConfPath) or {}

	--gm指令
	local gmlistFile = ret.gmlist_file or "gmlist.txt"
	local gmPath = string.format("../../conf/%s", gmlistFile)
	ret.gmlist = readLinesInFile(gmPath) or {}

	--反加速配置
	local antiFastmsgFile = ret.anti_fastmsg_conf_file
	if antiFastmsgFile and antiFastmsgFile ~= "" then
		local antiFastmsgPath = string.format("../../conf/%s", antiFastmsgFile)
		ret.anti_fastmsg_conf = loadLuaStyleConf(antiFastmsgPath) or {}
	else
		ret.anti_fastmsg_conf = {}
	end

	--解析生成免流配置
	parse_freeflow_redirect(ret)

	return ret
end

function command.reload()
	globalconf = loadconf()
	logger.info("globalconf = %s", futil.toStr(globalconf))
	if globalconf then
		sharedata.update("globalconf", globalconf)
		logger.info("globalconf reloaded")
	end
end

local function set(p, val, np)
	if np < 1 then return end
	local t = globalconf
	for i = 1, np - 1 do
		local k = p[i]
		t = t[k]
	end
	local k = p[np]
	t[k] = val
	return true
end

function command.set(...)
	local p = {...}
	local np = #p
	if np < 2 then
		logger.warn("globalconf set fail, count of parameter less than 2")
		return
	end
	local ok, changed = pcall(set, {...}, p[np], np - 1)
	if ok then
		if changed then 
			sharedata.update("globalconf", globalconf)
		end
		logger.info("globalconf set success")
		return true
	end
	logger.warn("globalconf set fail, error: %s", changed)
end

skynet.start(function ()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		return skynet_util.lua_docmd(command, session, string.lower(cmd), ...)
    end)

	globalconf = loadconf()
	logger.info("globalconf = %s", futil.toStr(globalconf))
	if globalconf then
		sharedata.new("globalconf", globalconf)
		logger.info("globalconf inited")
	end

	skynet.register ".globalconfloader"

	-- don't call skynet.exit()
end)
