local cjson = require "cjson"
local print_t = require "print_t"

local packer = {}

cjson.encode_sparse_array(true, 1, 1)

function packer.pack (v)
	--print_t(v)

	local ok, res_json = pcall(function() 
		return cjson.encode(v) 
	end)

	if ok then
		--print("cjson encode:"..res_json)
		return res_json
	else
		return nil
	end
end

function packer.unpack (v)
	--print("unpack:"..v)

	local ok, res_data = pcall(function() 
		return cjson.decode(v) 
	end)

	if ok then
		--print_t(res_data)
		return res_data
	else
		return nil
	end
end

return packer
