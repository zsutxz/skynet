local libsql_split = require "libsql_split"
local divide_conf = require "divided_conf"

libsql_split.load_divide_conf(divide_conf)
libsql_split.travel_divide_conf()
--sql type 1 (select ,delete):
--local sql = "select * from account where userid in (20032,31,344233) ;"
--
--日期
--local sql = "select * from logtest where logdate='2015-3-12 3:54:44'; "
--local sql = "select * from logtest where '2015-3-12 3:54:44'; "
--local sql = "select * from logtest lt where lt.logdate in('2015-2-3 12:23:23','2016-7-14','2016-7-14 12:21:00','2016-7-14 3:3:3','2017-3-1');"

--local sql = "select * from account as at ,account_info at_info where at.userid = 4 and at.userid = at_info.userid ;"
--local sql = "select * from account as at join account_info at_info on at.userid = 4 and at.userid = at_info.userid ;"
--local sql = "select * from account as at join account_info at_info on at.userid = 43243434 and at.userid = at_info.userid ;"

--sql type 2 (update):
--local sql = "update account at set name = 'robot_323' where at.userid=32323332"
--local sql = "update account at set name = 'robot_323' where userid in (3232,123333)"
--
--sql type 3 (insert ,replace):
--local sql = "insert into account at (at.userid,name) values(331234,'name');"
--local sql = "insert into account at (name,mymy,userid) values('name',23,1331234);"
--local sql = "insert into logtest lt (lt.uid, lt.logdate) values(333,'2/3/2015 12:23:23');"
--local sql = "insert into logtest (name, logdate) values('','2015-07-14 12:23:23');"
local sql = "insert into db_record.LoginLog ( `UserId` , `Ip` , `DeviceID` , `SystemType` , `SystemBrand` , `SystemResolution` , `KernalVersion` , `Createdate` ) values( -20192 , '127.0.0.1' , '' , - 1 , '' , '' , '' , '2016-08-18 16:24:46' )"
--local sql = "replace into account (userid,name) values(441324,'name'),(32344,'name');"

--local sql = "delete from db_test.account at where at.userid = 323332;"

--local sql = "select * from db_test.account where `userid` = 32 and `order`='asdf';"
--local sql = "select at.uid , at_info.name from account at join db_player.account_info at_info on at_info.name like 'robot_' and at.userid = at_info.userid and at.userid=40000 join account_detail at_detail on at_detail.userid = at.userid;"

local beg = os.clock()

--[[
for i = 0,10000000 do
    ok,sqls= libsql_split.sql_csplit("db_test",sql)
end
--]]

--local sql = "select * from account as at ,account_info at_info where at.userid in (34) and at.userid = at_info.userid and at_info.name like 'robot_';"
-- local sql = "select at.uid , account_info.name from account_info join db_player.account as at on at.userid = 4 and account_info.name like 'robot_' and at.userid = account_info.userid;"
local ok,sqls = libsql_split.sql_csplit("db_test",sql)

local endt = os.clock()
print(string.format("执行时间 ：%.8f",endt-beg))
print("=========================")
if ok == 0 then
    print("sqls:",sqls)
else
    print("error:",sqls)
end



