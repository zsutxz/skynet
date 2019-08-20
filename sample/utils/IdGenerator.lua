local IdGenerator = class("IdGenerator")

function IdGenerator:ctor() 
	self.id = 0
end

function IdGenerator:generate()
	return self:inc(1)
end

function IdGenerator:inc(val)
	self.id = self.id + val
	if (self.id > 2000000000) then
		self.id = 1
	end
	return self.id
end
return IdGenerator
