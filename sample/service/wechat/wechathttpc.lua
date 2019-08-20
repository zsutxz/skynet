local skynet = require "skynet"
local httpc = require "http.httpc"
local dns = require "dns"
local cjson = require "cjson"
local packer = require "packer"
local print_t = require "print_t"
local logger = require "logger"
local service = require "service"
local md5 = require "md5"

local des_encrypt = require "des_encrypt"

local wechathttpc = {}

--把输入数据串转换成可见的数字或大写字母（16进制）
--1、unsigned char表示为16进制数字；2、把16进制数字转化为2个8位字符
--如79：1、转为16进制数字：0x4F，2、使用两个8位字符存储：‘4’，‘F’。
local function BaseEncode(indata)

    local outdata = nil
    local temp_data = nil
    local temp_num = nil
	
    for i = 1, #indata do
        --print("in BaseEncode "..i..","..string.byte(indata,i,i))
        temp_num = tonumber(string.byte(indata,i,i))
        --高四位
        temp_data = math.floor(temp_num/16)
        if outdata == nil then
            if temp_data<10 then
                outdata = string.char(48+temp_data)
            else
                outdata = string.char(65+temp_data-10)
            end
        else
            if temp_data<10 then
                outdata = outdata..string.char(48+temp_data)
            else
                outdata = outdata..string.char(65+temp_data-10)
            end
        end

        --低四位
        temp_data = temp_num%16
        if outdata == nil then
            if temp_data<10 then
                outdata = string.char(48+temp_data)
            else
                outdata = string.char(65+temp_data-10)
            end
        else
            if temp_data<10 then
                outdata = outdata..string.char(48+temp_data)
            else
                outdata = outdata..string.char(65+temp_data-10)
            end
        end
	end

    return outdata 
end

local function gettime()
    local account_info = {}

    local userurl ="/index.php/Api/GetTime/index" 
	local ok, code, body = pcall(httpc.get,"sealywxb.lkgame.com",userurl)

    if not ok or code ~= 200 then
        skynet.error("http verify fail,code",tostring(code))
        account_info.errCode = 110 
        account_info.err='http request fail'
        return account_info
    end

    local ok, verify_ret = pcall(cjson.decode,body)
    if not ok then
        skynet.error('http verify return json decode err:%s',tostring(verify_ret))
        --返回消息错误
        account_info.errCode = 111
        account_info.err='http verify fail'
        return account_info
    else
		--print_t(verify_ret)
        if verify_ret.errcode==0 then

            logger.info("http verify ok, time:%s",tostring(verify_ret.time))

            account_info.errCode = verify_ret.errcode
            account_info.err = verify_ret.errmsg
            account_info.time = verify_ret.time
            return account_info
        end
    end

    return account_info
end

local function getsign(instr)
	local temp_token = "&token="
	temp_token = temp_token..math.random(1,9)..math.random(0,9)..math.random(0,0)..math.random(0,9)
    temp_token = temp_token..math.random(0,9)..math.random(0,9)..math.random(0,0)..math.random(0,9)
   
    instr = instr..temp_token

    local temp_in = instr.."&key=hp53fksc5doj65pr"

    return instr,md5.sumhexa(temp_in)
end

function wechathttpc.ackpay(args)
    local respheader = {}
    local url = "sealywxb.lkgame.com"

    local postfield = "/index.php/Api/Player/pay_ok?incharges_id="..args.incharges_id
    
    --local temptable = packer.unpack(args)
	--print_t(temptable)

    local account_info = gettime();
    if(account_info.errCode==0) then 
        postfield= postfield.."&time="..tostring(account_info.time)
    end
    
    local sign_str

    postfield,sign_str = getsign(postfield)

    postfield = postfield.."&sign="..sign_str
    
    --url = url..postfield
    print(url.."  "..postfield)
    local status, body = httpc.get(url, postfield, respheader)
end

function wechathttpc.logout(openid,qrscene)

    local respheader = {}
    local url = "sealywxb.lkgame.com"

    if openid == nil then
        return 
    end

    local postfield = "/index.php/Api/Player/login_out?openid="..openid

    logger.info("in wechathttpc logout,openid:%s,qrscene:%s",openid,qrscene)
    --加盐
    qrscene = string.char(math.random(0,255))..string.char(math.random(0,255))..qrscene

    local len, tempqrscene = des_encrypt.wc_encode(qrscene)
    local temp_str = tostring(BaseEncode(tempqrscene))

    postfield = postfield.."&qrscene="..temp_str

    local account_info = gettime();
    if(account_info.errCode==0) then 
        postfield= postfield.."&time="..tostring(account_info.time)
    end
    
    local sign_str

    postfield,sign_str = getsign(postfield)

    postfield = postfield.."&sign="..sign_str
    
    logger.info("url:%s,postfield:%s",url,postfield)
    local status, body = httpc.get(url, postfield, respheader)

    --清除微信端的登录信息
    local wechathandler = skynet.uniqueservice "wechathandler"
    skynet.call(wechathandler,"lua","clearopenid",openid)

    logger.info("httc return status:%s,body:%s",status,body)

end

function wechathttpc.gameover(room_id,countdown,race_info)

    local respheader = {}
    local url = "sealywxb.lkgame.com"
    
    local racedata = "["

    --拼接传给微信的字符串
    for k,v in pairs(race_info) do
        local info = packer.pack(v)
        racedata = racedata..info..","
	end

    --去掉最后一个逗号，加上一个中括号
    if #racedata > 1 then
        racedata =  string.sub(racedata,0,string.len(racedata)-1).."]"
    else    --没有值
        racedata = racedata.."]"
    end

    local postfield = "/index.php/Api/Race/end_race?room_id="..tostring(room_id).."&countdown="..tostring(countdown).."&race_info="..racedata

    local account_info = gettime();
    if(account_info.errCode==0) then 
        postfield= postfield.."&time="..tostring(account_info.time)
    end
    
    local sign_str

    postfield,sign_str = getsign(postfield)

    postfield = postfield.."&sign="..sign_str
    
    logger.info("url:%s,postfield:%s",url,postfield)
    local status, body = httpc.get(url, postfield, respheader)

    logger.info("httc return status:%s,body:%s",status,body)

end

function wechathttpc.end_stand_alone(openid,score,countdown,qrscene)

    local respheader = {}
    local url = "sealywxb.lkgame.com"

    if openid == nil then
        return 
    end

    local postfield = "/index.php/Api/Race/end_stand_alone?openid="..openid

    logger.info("in wechathttpc end_stand_alone,openid:%s,qrscene:%s",openid,qrscene)
    --加盐
    qrscene = string.char(math.random(0,255))..string.char(math.random(0,255))..qrscene

    local len, tempqrscene = des_encrypt.wc_encode(qrscene)
    local temp_str = tostring(BaseEncode(tempqrscene))

    postfield = postfield.."&qrscene="..temp_str
    postfield = postfield.."&point="..score
    postfield = postfield.."&countdown="..countdown

    local account_info = gettime();
    if(account_info.errCode==0) then 
        postfield= postfield.."&time="..tostring(account_info.time)
    end
    
    local sign_str

    postfield,sign_str = getsign(postfield)

    postfield = postfield.."&sign="..sign_str
    
    logger.info("url:%s,postfield:%s",url,postfield)
    local status, body = httpc.get(url, postfield, respheader)

    logger.info("httc return status:%s,body:%s",status,body)

end

skynet.start(function()
	httpc.dns()	-- set dns server
	--skynet.exit()
end)

service.init {
	command = wechathttpc,
    require = {
		-- "wechatgate"
	}
}
