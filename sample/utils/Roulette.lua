local logger = require "logger"
-- 轮盘赌算法
local Roulette = class("Roulette")

function Roulette:ctor(values,weights)
	assert(#values==#weights, "2个参数长度必须一致")
	self.values = values
	self.weights = weights
	self.sum_weight = 0
	for i=1, #self.weights do
		self.sum_weight = self.sum_weight + self.weights[i]
	end
end

function Roulette:roll()
	if self.sum_weight == 0 then
		logger.err(debug.traceback())
		return self.values[1], 1
	end

	local slice = math.random() * self.sum_weight
	local weight = 0
	for i=1, #self.weights do
		weight = weight + self.weights[i]
		if slice <= weight then
			return self.values[i], i 
		end
	end
	return self.values[1], 1
	
end

-- 从配置文件(table)中构建轮盘
function create_roulette_by_config(configs, vkey, wkey)
	local ids = {}
	local weights = {}
	for k, v in pairs(configs) do
		table.insert(ids, v[vkey])
		table.insert(weights, v[wkey])
	end
	return Roulette.new(ids, weights)
end

-- 从配置文件(table)中构建轮盘
function create_roulette_by_config_cfgkey(configs, wkey)
	local ids = {}
	local weights = {}
	for k, v in pairs(configs) do
		table.insert(ids, k)
		table.insert(weights, v[wkey])
	end
	return Roulette.new(ids, weights)
end


return Roulette
