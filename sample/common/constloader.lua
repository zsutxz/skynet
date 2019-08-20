local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "skynet_util"
local sharedata = require "sharedata"
local logger = require "logger"
local lfs = require "lfs"

local CMD = {}
local const

local function readconfig(file)
	return load(file:read("*a"))()
end

local function loadconfig(path)
	local file = io.open(path)
	if not file then
		logger.err("constloader load config error, file not found path:%s",path)
		error("file not found!")
	end
	local ok, conf = xpcall(readconfig, skynet_util.handle_err, file)
	file:close()
	if not ok then
		logger.err("constloader read file error: %s", conf)
		error("read file fail!")
	end
	return conf
end

local function set(p, val, np)
	if not np then np = #p end
	if np < 1 then return end
	local t = const
	for i = 1, np-1 do
		local k = p[i]
		t = t[k]
	end
	local k = p[np]
	t[k] = val
	return true
end

function CMD.reload()
	local ok, new_const = pcall(loadconfig, "common/const.lua")
	if ok and new_const then
		const = new_const
		sharedata.update("const", const)
		logger.info("const reload success")
		return true
	end
	logger.warn("const reload fail, error:%s", new_const)
end

function CMD.unset(...)
	local ok, changed = pcall(set, {...})
	if ok then
		if changed then
			sharedata.update("const", const)
		end
		logger.info("const unset success")
		return true
	end
	logger.warn("const unset fail, error:%s", changed)
end

function CMD.set(...)
	local p = {...}
	local np = #p
	if np < 2 then
		return logger.warn("const set fail, count of parameter less than 2")
	end
	local ok, changed = pcall(set, {...}, p[np], np-1)
	if ok then
		if changed then
			sharedata.update("const", const)
		end
		logger.info("const set success")
		return true
	end
	logger.warn("const set fail, error:%s", changed)
end

skynet.init(function ()
	const = loadconfig("common/const.lua")
	sharedata.new("const", const)
	logger.info("const loaded")
end)

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, cmd, ...)
		return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
	skynet.register(".constloader")
end)
