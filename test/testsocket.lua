local skynet = require "skynet"
local socket = require "socket"

local mode , id = ...

local function echo(id)
	socket.start(id)
	socket.write(id, "Hello Skynet\n")
	while true do
		local str = socket.read(id)
		if str then
			print(str)
			socket.write(id, "send socket")
		else
			print("clost socket!")
			socket.close(id)
			return
		end
	end
end

if mode == "agent" then
	id = tonumber(id)
	print("agent:"..id)
	skynet.start(function()
		skynet.fork(function()
			echo(id)
			skynet.exit()
		end)
	end)
else
	local function accept(id)
		socket.start(id)

		--socket.write(id, "Hello Skynet\n")

		skynet.newservice(SERVICE_NAME, "agent", id)
		-- notice: Some data on this connection(id) may lost before new service start.
		-- So, be careful when you want to use start / abandon / start .
		socket.abandon(id)
	end

	skynet.start(function()

		local id = socket.listen("0.0.0.0", 6666)
		skynet.error(string.format("socket listening on %s:%d", "0.0.0.0", 6666))

		socket.start(id , function(id, addr)
			print("connect from " .. addr .. " " .. id)
			-- you have choices :
			-- 1. skynet.newservice("testsocket", "agent", id)
			-- 2. skynet.fork(echo, id)
			-- 3. accept(id)
			skynet.newservice("testsocket", "agent", id)
		end)
	end)
end