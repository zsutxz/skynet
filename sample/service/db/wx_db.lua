local wx_db = {}

wx_db.insert_accounts = {
    sql = "insert into wx_db.tb_player (login_id, password, nickname,login_id) values (\"$account\", \"$pwd\", \"$nickname\",NOW() );"
}

wx_db.load_accounts = {
	sql = [[select * from wx_db.tb_player where login_id = $account]]
}

wx_db.select_max_machid = {
    sql = "select max(mach_id) as max_id from wx_db.tb_machine;"
}

wx_db.insert_machine = {
    sql = "insert into wx_db.tb_machine (game_id, mach_id,company_id, store_id,locked,add_time,spec) values ($game,$machid,$company,$store,$locked,\"time\",\"test\");"
}

wx_db.load_machine_info = {
    sql = "select * from wx_db.tb_machine where game_id = $game and mach_id = $machid;"
}
	
-- charge order
wx_db.insert_player_charge_order={
    sql = "insert into tb_incharge (player_login_id, incharges_id, game_id,mach_id,play_no,total_fee,is_incharged,incharge_t) values(\"$openid\",$incharges_id,\"$game_id\",\"$mach_id\", $play_no,$total_fee,$is_incharged,NOW() ); "
}

wx_db.load_player_charge_order={
    sql = "select * from tb_incharge where incharges_id = $incharges_id;"
}

wx_db.insert_player_record={
    sql = "insert into tb_record (player_login_id, game_id,mach_id,play_no,kind_id,value,create_t) values(\"$openid\",\"$game_id\",\"$mach_id\", $play_no,$kind_id,$value,NOW() ); "
}

--查询某个玩家在某台机的记录
wx_db.load_player_charge_order={
    sql = "select * from tb_record where player_login_id = $player_login_id and game_id = $game and mach_id = mach_id;"
}

wx_db.set_login_info = {
    redis = "hmset logininfo:$uid fd $fd nodename $nodename server_ip $server_ip server_port $server_port",
    cachekey = 'logininfo:$uid',
    expire = 30,
}

-- 房间信息
wx_db.insert_room = {
    sql = "insert into wx_db.tb_room_info (name,id,create_t) values (\"$name\",$room_id,\"$time\");"
}

wx_db.select_last_room_id = {
    sql = "select max(id) as last_id from wx_db.tb_room_info;"
}


return wx_db
