require "functions"

local subject = class("subject")

function subject:ctor(main_type, sub_type)
	self.main_type = main_type
	self.sub_type = sub_type
	self.observers = {}
end

function subject:regist(observer)
	table.insert(self.observers, observer)
end

function subject:unregist(observer)
	for k,v in pairs(self.observers) do
		if(v == observer) then
			table.remove(self.observers, k)
			break
		end
	end
end

function subject:notify(data)
	for _, v in pairs(self.observers) do
		v:on_event(self.main_type, self.sub_type, data)
	end
end
