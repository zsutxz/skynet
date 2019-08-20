require "table_util"
function interface(interface_name, super)
	local superType = type(super)
	local inter = {}

	if superType ~= "table" then
		superType = nil
		super = nil
	end

	inter.__self_define_type = "interface"
	inter.__interface_name = interface_name
	if super and super.__funs then
		inter.__funs = super.__funs
	else
		inter.__funs = {}
	end
	inter.__funs.__interface = inter

	local mt = {
		__index = function(t, func_name)
			if type(inter.__funs) == "table" and inter.__funs[func_name] then
				if func_name ~= '__interface' then
					print("function " .. func_name .. " of interface " .. interface_name .. " is not implemented")
				end
				return inter.__funs[func_name]
			end
		end,
	}	
	setmetatable(inter, mt)

	return inter.__funs
end


function implements(impl, interface_list)
	if not impl then
		impl = {}
	end

	local type_impl = type(impl)
	if type_impl ~= "table" then
		error("impl is not an table!")
	end	

	for i, inter_funs in ipairs(interface_list) do
		local inter = inter_funs.__interface
		local type_inter = type(inter)

		if type_inter ~= "table" or inter.__self_define_type ~= "interface" then
			error("implemented table is not an interface!")
		end

		if not impl.__interfaces then
			impl.__interfaces = {}
		end
		impl.__interfaces[inter.__interface_name] = inter		
	end

	local old_metatable = getmetatable(impl)
	local old_index = nil
	if old_metatable then
		old_index = old_metatable.__index
	end

	local mt = {
		__index = function(t, k)
			if old_index and old_index[k] then
				return old_index[k]
			end
			return nil
		end,	
	}
	setmetatable(impl, mt)

	function impl:get_interface(interface_name)
		if not self.__interfaces then
			return nil
		end
		local inter = self.__interfaces[interface_name]
		if not inter then
			return nil
		end

		if not self.__interface_instance then
			self.__interface_instance = {}
		end
		if self.__interface_instance[interface_name] then
			return self.__interface_instance[interface_name]
		end
		local result = {}		
		result.__impl = self
		for k, v in pairs(inter.__funs) do
			if self[k] then
				result[k] = function (t, ...)
					return t.__impl[k](t.__impl, ...)
				end
			end
		end

		self.__interface_instance[interface_name] = result
		return result
	end
	
	return impl
end
