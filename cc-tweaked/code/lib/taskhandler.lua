local m = {}

m.taskQueue = {}
m.taskEvent = "task_todo"

--## Main Runtime ##--

local taskStructure = {
	"taskname",
	{ "param1", "param2", "param3", "etc." },
}

local handlerFuncsTemplate = {
	["taskname"] = function(param1, param2, param3)
		print(param1)
	end,
}

local dispatchFuncsTemplate = {
	["modem_message"] = function(self, side, channel, replychannel, message, distance) end,
	["rednet_message"] = function(self, senderID, message, protocol) end,
	["mouse_click"] = function(buttonPressed, xCoord, yCoord) end,
	["mouse_scroll"] = function(dir, xCoord, yCoord) end,
	["key"] = function(keyID, heldDown)
		if keyID == keys.delete then
			error({ message = "physical KILLswitch pressed", code = 500 })
		end
	end,
}

m.queueTask = function(self, task)
	table.insert(self.taskQueue, task)
	os.queueEvent(self.taskEvent)
end

m.handler = function(self)
	while true do
		os.pullEvent(self.taskEvent)
		while #self.taskQueue > 0 do
			local task = table.remove(self.taskQueue, 1)
			local taskName = task[1]
			local taskParams = task[2]
			local taskFunc = self.handlerFuncs[taskName]
			if self.instance ~= nil then
				taskFunc(self.instance, table.unpack(taskParams))
			else
				taskFunc(table.unpack(taskParams))
			end
		end
	end
end

m.dispatcher = function(self)
	local userKeyFunc = self.dispatchFuncs.key_up
	if self.instance ~= nil then
		self.dispatchFuncs.key_up = function(instance, keyID)
			if keyID == keys.delete then
				error({ message = "physical KILLswitch pressed", code = 500 })
			elseif userKeyFunc ~= nil then
				userKeyFunc(instance, keyID)
			end
		end
	else
		self.dispatchFuncs.key_up = function(keyID)
			if keyID == keys.delete then
				error({ message = "physical KILLswitch pressed", code = 500 })
			elseif userKeyFunc ~= nil then
				userKeyFunc(keyID)
			end
		end
	end
	while true do
		local event = { os.pullEvent() }

		if self.dispatchFuncs[event[1]] ~= nil then
			if self.instance ~= nil then
				self.dispatchFuncs[event[1]](self.instance, table.unpack(event, 2))
			else
				self.dispatchFuncs[event[1]](table.unpack(event, 2))
			end
		end
	end
end

m.run = function(self, dispatchFuncs, handlerFuncs, instance)
	if dispatchFuncs == nil or handlerFuncs == nil then
		error("one or both functions are nil")
	end
	self.dispatchFuncs = dispatchFuncs
	self.handlerFuncs = handlerFuncs
	if instance ~= nil then
		self.instance = instance
	end
	while true do
		local success, exception = pcall(function()
			parallel.waitForAny(function()
				self:dispatcher()
			end, function()
				self:handler()
			end)
		end)
		if not success and exception ~= nil then
			if exception.code ~= nil then
				if exception.code ~= 500 then
					print(exception.message)
				else
					error(exception.message)
				end
			else
				error(exception)
			end
		end
	end
end

m.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	return o
end

return m
