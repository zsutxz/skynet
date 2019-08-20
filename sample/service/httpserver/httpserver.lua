local skynet = require "skynet"
local socket = require "socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local service = require "service"
local table = table
local string = string
local webrouter = require "http_webrouter"

local httpserver = {}
local mode = ...

if mode == "agent" then

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local function response_static_resource(id, path)
	local f = io.open(path, "r")
	if not f then
		return response(id, 404, "not found")
	end
	local data = f:read("*a")
	f:close()
	return response(id, 200, data)
end

skynet.start(function()

	local webroot = "/"
	local webrouter = require("http_webrouter")
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)
		
		-- limit request body size to 8192 (you can pass nil to unlimit)
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		
		--skynet.error(string.format("http receive data id:%s,code:%s",id,code))

		if code then
			if code ~= 200 then
				response(id, code)
			else
				local querystr = {}
				local tmp = {}
				if header.host then
					table.insert(tmp, string.format("host: %s", header.host))
				end
				--skynet.error("url: %s",url)
				local path, query = urllib.parse(url)
				table.insert(tmp, string.format("path: %s", path))
				if query then
					querystr = urllib.parse_query(query)
					for k, v in pairs(querystr) do
						table.insert(tmp, string.format("query: %s= %s", k,v))
						--print("querystr:"..k.." "..v)
					end
				end
				table.insert(tmp, "-----header----")
				for k,v in pairs(header) do
					table.insert(tmp, string.format("%s = %s",k,v))
				end
				table.insert(tmp, "-----body----\n" .. body)
				
				local f = webrouter and webrouter["wechat"]

				if f == nil then
					if not webroot then
						response(id, 404, "not found")
					else
						response_static_resource(id, string.format("%s%s", webroot, path))
					end
				else
					if type(f) == "function" then
						response(id, f(method, header, tmp, querystr))
					else
						response(id, 200, tostring(f))
					end
				end
				--response(id, code, "ok")
			end
		else
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)

else

skynet.start(function()
	local agent = {}
	for i= 1, 20 do
		agent[i] = skynet.newservice(SERVICE_NAME, "agent")
	end
	local balance = 1
	local id = socket.listen("127.0.0.1", 8004)
	skynet.error("Listen web port 8004")
	socket.start(id , function(id, addr)
		--skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)

end
