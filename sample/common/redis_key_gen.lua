local futil = require "futil"
local mod = {} 

function mod.user_pos(openid)
	return string.format("upos:%s", openid)
end

function mod.wawaji_pos(wawaji_id)
	return string.format("wawapos:%s", wawaji_id)
end

function mod.game_machine_pos(game_id, machine_id)
	return string.format("machinepos:%s_%s", game_id, machine_id)
end

function mod.room_pos(room_id)
	return string.format("room_pos:%s", room_id)
end

function mod.room_master()
	return "room_master"
end

function mod.room_server()
	return "room_server"
end

function mod.room_ids()
	return "room_ids"
end

function mod.sms_verify(phone)
	return string.format("sms_verify_%s", phone)
end

function mod.idip_req_lock(key)
	return string.format("idip_req_lock:%s", key)
end


return mod
