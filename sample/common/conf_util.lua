local skynet = require "skynet"
local query_sharedata = require "query_sharedata"

--[[
此模块封装一些常用的配置的获取
方便其他模块调用
]]

local const
local globalconf
local game_switch_info
local conf_util = {}

function conf_util.get_core_bgsave_interval()
	return (globalconf.player_core_bgsave_interval or const.db.core_bgsave_interval)
end

function conf_util.get_non_core_bgsave_interval()
	return (globalconf.player_non_core_bgsave_interval or const.db.non_core_bgsave_interval)
end

function conf_util.get_check_active_interval()
	return (globalconf.max_inactive_time / 2 or const.check_active.default_interval)
end

function conf_util.is_ios_review(phone_platform)
	return phone_platform == const.phone_plat.ios and globalconf.ios_review and globalconf.ios_review == 1
end

function conf_util.is_load_stat_enabled()
	return globalconf.load_stat_enable and globalconf.load_stat_enable == 1
end

function conf_util.get_load_stat_interval()
	return globalconf.load_stat_interval or 1800
end

function conf_util.get_cmdstat_service_output_interval()
	return globalconf.cmdstat_service_output_interval or const.cmd_stat.default_output_interval
end

function conf_util.get_profile_mem_sampling_interval()
	return globalconf.profile_mem_sampling_interval or const.profile.mem_sampling_interval
end

skynet.init(function()
	const = query_sharedata "const"
	globalconf = query_sharedata "globalconf"
end)


return conf_util
