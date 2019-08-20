local skynet = require "skynet"
require "skynet.manager"
local skynet_util = require "skynet_util"
local sharedata = require "sharedata"
local logger = require "logger"
local lfs = require "lfs"

local config_names_path, config_converters_path = ...
local config_names
local config_converters
local all_configs

local function readconfig(file)
	return load(file:read("*a"))()
end

local function loadconfig(name)
	local path = string.format("../../res/%s.lua", name:gsub("%.", "/"))
	local file = io.open(path)
	if not file then
		logger.err("configsloader loadconfig error: file not found, path=%s", path)
		error("file not found! path=".. path)
	end
	local ok, conf = xpcall(readconfig, skynet_util.handle_err, file)
	file:close()
	if not ok then
		logger.err("configsloader loadconfig read file path=%s error:%s", path, conf)
		error("read file fail! path="..path)
	end
	if config_converters and config_converters[name] then
		return config_converters[name](conf)
	end
	return conf
end

local function walk(root, dir, rlst)
	if not rlst then rlst = {} end
	local path = dir and string.format("%s/%s", root, dir) or root
	for f in lfs.dir(path) do
		if f ~= "." and f ~= ".." then
			local attr = lfs.attributes(path.."/"..f)
			if attr.mode == "file" then
				table.insert(rlst, dir and string.format("%s/%s", dir, f) or f)
			elseif attr.mode == "directory" then
				walk(root, dir and string.format("%s/%s", dir, f) or f, rlst)
			else
				skynet.error("configsloader unkown file mode:", attr.mode)
			end
		end
	end
	return rlst
end

local function set(p, val, np)
	if not np then np = #p end
	if np < 1 then return end
	local t = all_configs
	for i = 1, np-1 do
		local k = p[i]
		t = t[k]
	end
	local k = p[np]
	t[k] = val
	return true
end

local CMD = {}

function CMD.reload(names)
	logger.info('configsloader reload')
	local changed_configs
	if not names then
		names = config_names
	else
		changed_configs = {}
	end
	for k, name in ipairs(names) do
		logger.info('configsloader reload %s', name)
		local ok, conf = pcall(loadconfig, name)
		if ok and conf then
			if not all_configs[name] then
				table.insert(config_names, name)
			end
			all_configs[name] = conf
			if changed_configs then changed_configs[name] = conf end
		else
			logger.warn("configs reload %s error:%s", name, conf)
		end
	end
	if config_converters and config_converters["."] then
		local ok, err = pcall(config_converters["."], all_configs, changed_configs)
		if not ok then
			logger.warn("configs convert error:%s", err)
		end
	end
	logger.info("configs reloaded")
	sharedata.update("configs", all_configs)
	if config_converters and config_converters[".."] then
		skynet.fork(config_converters[".."], all_configs, changed_configs)
	end
end

function CMD.unset(...)
	local ok, changed = pcall(set, {...})
	if ok then
		if changed then
			sharedata.update("configs", all_configs)
		end
		logger.info("configs unset success")
		return true
	end
	logger.warn("configs unset fail, error:%s", changed)
end

function CMD.set(...)
	local p = {...}
	local np = #p
	if np < 2 then
		return logger.warn("configs set fail, count of parameter less than 2")
	end
	local ok, changed = pcall(set, {...}, p[np], np-1)
	if ok then
		if changed then
			sharedata.update("configs", all_configs)
		end
		logger.info("configs set success")
		return true
	end
	logger.warn("configs set fail, error:%s", changed)
end

skynet.init(function ()
	if config_names_path then
		config_names = require(config_names_path)
	else
		local files = walk("../../res")
		for i = 1, #files do
			files[i] = files[i]:sub(1, -5):gsub("/", ".")
		end
		config_names = files
	end
	if config_converters_path then
		config_converters = require(config_converters_path)
	end
	all_configs = {}
	for k, name in ipairs(config_names) do
		local ok, conf = xpcall(loadconfig, skynet_util.handle_err, name)
		if not ok then
			error(string.format("load %s fail", name))
		end
		all_configs[name] = conf
	end
	if config_converters and config_converters["."] then
		config_converters["."](all_configs)
	end
	sharedata.new("configs", all_configs)
	logger.info("configs loaded")
end)

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, cmd, ...)
		return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
	skynet.register(".configsloader")
end)
