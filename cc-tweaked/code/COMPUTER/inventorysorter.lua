local filterassigner = require("ui/filterassigner")
local taskhandler = require("lib/taskhandler"):new()

local args = { ... }
if #args < 1 then -- or #args > 1) then
	print("Computer will manage input chests, output chests that have filters.")
	print("Register a filter with 'inventorysorter register'.")
	print()
	print("usage: inventorysorter <register or run>")
	error()
end

--## Program Globals ##--

local sorter = nil
local m = {}
m.inputs = {}
m.outputs = {}
m.filters = {}
m.wrapped = {}

--## Variables to track state ##--
m.chestDir = "chests"
m.cinputFile = "input.clist"
m.coutputFile = "output.clist"
m.cfilterFile = "filter.clist"

m._timerID = nil -- main loop
m._pollRate = 7 -- seconds

--## Chest ManagementHelper Functions ##--

m.getPeripherals = function(self)
	local peripheralList = {}
	for _, pName in ipairs(peripheral.getNames()) do
		if string.find(pName, "chest") then
			table.insert(peripheralList, pName)
		elseif
			pName ~= "bottom"
			and pName ~= "top"
			and pName ~= "left"
			and pName ~= "right"
			and pName ~= "front"
			and pName ~= "back"
		then
			local types = { peripheral.getType(pName) }
			for i = #types, 1, -1 do
				if types[i] == "inventory" then
					table.insert(peripheralList, pName)
					break
				end
			end
		end
	end
	return peripheralList
end

m.cullOutputs = function(self)
	for i = #self.outputs, 1, -1 do
		if self.outputs[i].hasFilter then
			table.remove(self.outputs, i)
		end
	end
end

m.wrapChests = function(self)
	for _, subType in ipairs({ self.inputs, self.outputs, self.filters }) do
		for _, chest in ipairs(subType) do
			self.wrapped[chest.name] = peripheral.wrap(chest.name)
		end
	end
end

m.hasChestsAssigned = function(self, peripheralList)
	return #peripheralList == #self.inputs + #self.outputs + #self.filters
end

m.assignChests = function(self, peripheralList)
	local assigner = filterassigner:new(peripheralList, self.inputs, self.outputs, self.filters)
	local assignments = assigner:run(term.native())
	for subType, chest in pairs(assignments) do
		if subType == "Input" then
			self.inputs = chest
		elseif subType == "Output" then
			self.outputs = chest
		elseif subType == "Filter" then
			self.filters = chest
		end
	end
end

m.saveChests = function(self)
	local chestDir = ""
	if self.chestDir ~= "" then
		chestDir = self.chestDir .. "/"
	end
	if not fs.exists(self.chestDir) then
		fs.makeDir(self.chestDir)
	end

	local handle = fs.open(chestDir .. self.cinputFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.inputs))
		handle.close()
	end

	handle = fs.open(chestDir .. self.coutputFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.outputs))
		handle.close()
	end

	handle = fs.open(chestDir .. self.cfilterFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.filters))
		handle.close()
	end
end

m.loadChests = function(self)
	local chestDir = ""
	if self.chestDir ~= "" then
		chestDir = self.chestDir .. "/"
	end

	if fs.exists(chestDir .. self.cinputFile) then
		local handle = fs.open(chestDir .. self.cinputFile, "r")
		if handle ~= nil then
			local inputListText = handle.readAll() or ""
			local inputListUnserialized = textutils.unserialize(inputListText)
			if type(inputListUnserialized) == "table" then
				self.inputs = inputListUnserialized
			end
			handle.close()
		end
	end

	if fs.exists(chestDir .. self.coutputFile) then
		local handle = fs.open(chestDir .. self.coutputFile, "r")
		if handle ~= nil then
			local outputListText = handle.readAll() or ""
			local outputListUnserialized = textutils.unserialize(outputListText)
			if type(outputListUnserialized) == "table" then
				self.outputs = outputListUnserialized
			end
			handle.close()
		end
	end

	if fs.exists(chestDir .. self.cfilterFile) then
		local handle = fs.open(chestDir .. self.cfilterFile, "r")
		if handle ~= nil then
			local filterListText = handle.readAll() or ""
			local filterListUnserialized = textutils.unserialize(filterListText)
			if type(filterListUnserialized) == "table" then
				self.filters = filterListUnserialized
			end
			handle.close()
		end
	end
end

--## Operation Functions ##--

m.mapInputInventory = function(self) --separate inventory in input
	local items = {} -- items with fuel removed as an unsorted array, with name, count, slot and chest captured
	local filterList = {} -- object with key as item name and value as array of output chest names to cycle through

	for _, chest in ipairs(self.filters) do
		for _, data in pairs(self.wrapped[chest.name].list()) do
			if filterList[data.name] == nil then
				filterList[data.name] = { lastIndex = 1, outputNames = { chest.pairName } }
			else
				table.insert(filterList[data.name].outputNames, chest.pairName)
			end
		end
	end

	for _, chest in ipairs(self.inputs) do
		for slot, data in pairs(self.wrapped[chest.name].list()) do
			local item = { name = data.name, count = data.count, slot = slot, chestName = chest.name }
			table.insert(items, item)
		end
	end
	return { items = items, filterList = filterList }
end

m._sortByStackCountDesc = function(a, b)
	return a.count > b.count
end

m._sortByStackCountAsc = function(a, b)
	return a.count < b.count
end

m.prioritizeItems = function(self, items) --re-sort list of items to smelt most important first
	table.sort(items, self._sortByStackCountDesc)
end

m.processInventory = function(self, mappedInventory)
	local items = mappedInventory.items
	local filterList = mappedInventory.filterList

	local outputChests = {}
	for _, outputChest in ipairs(self.outputs) do
		table.insert(outputChests, outputChest.name)
	end

	for _, item in ipairs(items) do
		local itemOutputChests = { table.unpack(outputChests) }
		local itemCount = item.count
		if filterList[item.name] ~= nil and filterList[item.name].outputNames ~= nil then
			table.insert(itemOutputChests, 1, filterList[item.name].outputNames[1])
		end

		for _, output in ipairs(itemOutputChests) do
			if itemCount > 0 then
				itemCount = itemCount - self.wrapped[item.chestName].pushItems(output, item.slot)
			end
		end
	end
end

m.processTasks = function(self)
	while true do
		local _ = { os.pullEvent("task_process") }
		while #self._taskStack > 0 do
			local instruction = table.remove(self._taskStack, 1)

			if instruction.task == "furnace_checkinput" then
				local mappedInventory = self:mapInventory()
				if
					not self.furnaceStack:isEmpty()
					and self:canSmelt(mappedInventory.items, mappedInventory.fuels, mappedInventory.fuelTiers)
				then
					self:processInventory(mappedInventory)
				end
			elseif instruction.task == "furnace_complete" and self.furnaces[instruction.furnace.index] ~= nil then
				local furnace = instruction.furnace
				self._furnaceTimers[instruction.timerID] = nil
				furnace:emptySmelt(self.outputs)
				self.furnaceStack:push(furnace)
				os.queueEvent("timer_furnaceavailable")
			end
		end
	end
end

m.checkTimers = function(self)
	while true do
		local event = { os.pullEvent() }
		local eventName = event[1]
		if eventName == "timer_furnaceloaded" then
			local timeout = event[2]
			local furnaceIndex = event[3]
			local newTimer = os.startTimer(timeout) -- time for timer
			self._furnaceTimers[newTimer] = self.furnaces[furnaceIndex] -- furnace
		elseif eventName == "timer_furnaceavailable" then
			table.insert(self._taskStack, { task = "furnace_checkinput" })
			os.queueEvent("task_furnace")
		elseif eventName == "timer" then
			local timerID = event[2]
			if timerID ~= nil and timerID == self._timerID then
				self._timerID = os.startTimer(self._pollRate)
				table.insert(self._taskStack, { task = "furnace_checkinput" })
				os.queueEvent("task_furnace")
			elseif self._furnaceTimers[timerID] ~= nil then -- found furnace
				local furnace = self._furnaceTimers[timerID]
				table.insert(self._taskStack, { task = "furnace_complete", furnace = furnace, timerID = timerID })
				os.queueEvent("task_furnace")
			end
		elseif eventName == "key" and event[2] == keys.delete then
			os.cancelTimer(self._timerID)
			term.clear()
			term.setCursorPos(1, 1)
			error("Manually cancelled operation")
		elseif eventName == "peripheral" then
			local peripheralName = event[2]
			if string.find(peripheralName, "furnace") then
				local furnace = Furnace:new(peripheralName)
				furnace.index = peripheralName
				self.furnaces[furnace.index] = furnace
				self:checkFurnace(furnace)
			end
		elseif eventName == "peripheral_detach" then
			local peripheralName = event[2]
			self:removeFurnace(peripheralName)
		end
	end
end

m.dispatchers = {
	["timer"] = function(self, timerID)
		taskhandler:queueTask({ "scan-inventory", {} })
	end,
}

m.handlers = {
	["scan-inventory"] = function(self)
		local mappedInventory = self:mapInputInventory()
		self:processInventory(mappedInventory)
		os.startTimer(5)
	end,
}

--## Constructor Method ##--

m.new = function(self) -- , t)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

--## Main Runtime ##--

os.setComputerLabel("" .. os.computerID())

if args[1] == "run" then
	sorter = m:new()
	local peripheralList = sorter:getPeripherals()
	sorter:loadChests()
	while not sorter:hasChestsAssigned(peripheralList) do
		sorter:assignChests(peripheralList)
		sorter:saveChests()
	end
	sorter:cullOutputs()
	sorter:wrapChests()
	os.startTimer(1)
	taskhandler:run(sorter.dispatchers, sorter.handlers, sorter)
elseif args[1] == "register" then
	sorter = m:new()
	sorter:getPeripherals()
	sorter:checkForFuelList()
	sorter:register()
	sorter:saveFuelList()
elseif args[1] == "test" then
	sorter = m:new()
	local peripheralList = sorter:getPeripherals()
	sorter:loadChests()
	while not sorter:hasChestsAssigned(peripheralList) do
		sorter:assignChests(peripheralList)
		sorter:saveChests()
	end
	sorter:cullOutputs()
	sorter:wrapChests()
elseif args[1] == "assign" then
	sorter = m:new()
	local peripheralList = sorter:getPeripherals()
	sorter:loadChests()
	sorter:assignChests(peripheralList)
	sorter:saveChests()
end
