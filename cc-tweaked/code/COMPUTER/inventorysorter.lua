local filterassigner = require("ui/filterassigner")

local args = { ... }
if #args < 1 then -- or #args > 1) then
	print("Computer will manage input chests, output chests that have filters.")
	print("Register a filter with 'inventorysorter register'.")
	print()
	print("usage: inventorysorter <register or run>")
	error()
end

--## Program Globals ##--

local inputs = {} -- placeholder for instance
local outputs = {
	filter = nil,
	output = nil,
}
local sorter = nil
local m = {}

--## Module ##--

local FurnaceStack = {}
FurnaceStack.stack = {}
FurnaceStack.push = function(self, furnace)
	self.stack[#self.stack + 1] = furnace
end
FurnaceStack.pop = function(self)
	if self:isEmpty() then
		return
	end
	local furnace = self.stack[#self.stack]
	self.stack[#self.stack] = nil
	return furnace
end
FurnaceStack.peek = function(self)
	return self.stack[#self.stack]
end
FurnaceStack.remove = function(self, index)
	local removed = self.stack[index]
	self.stack[index] = nil
	for i = index + 1, #self.stack, 1 do
		self.stack[i - 1] = self.stack[i]
		self.stack[i] = nil
	end
	return removed
end
FurnaceStack.isEmpty = function(self)
	return not (#self.stack > 0)
end
FurnaceStack.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

local Furnace = {}
Furnace.inputSlot = 1
Furnace.fuelSlot = 2
Furnace.outputSlot = 3
Furnace.index = ""
Furnace.isAvailable = function(self)
	return self and self.peripheral and self.peripheral.list()[1] == nil and self and self.peripheral.list()[2] == nil
end
Furnace.addFuel = function(self, inputChest, slot, limit)
	return self
		and self.peripheral
		and self.peripheral.pullItems(peripheral.getName(inputChest), slot, limit, self.fuelSlot)
end
Furnace.addItem = function(self, inputChest, slot, limit)
	return self
		and self.peripheral
		and self.peripheral.pullItems(peripheral.getName(inputChest), slot, limit, self.inputSlot)
end
Furnace.emptySmeltToOutput = function(self, outputChest)
	return self and self.peripheral and self.peripheral.pushItems(peripheral.getName(outputChest), self.outputSlot)
end
Furnace.emptySmelt = function(self, outputChests)
	if not self then
		return 0
	end
	local itemGrabbedCount = 0
	for _, chest in ipairs(outputChests) do
		if self.peripheral.list()[3] == nil then
			break
		end
		itemGrabbedCount = itemGrabbedCount + self:emptySmeltToOutput(chest)
	end
	return itemGrabbedCount
end
Furnace.new = function(self, peripheralName)
	local o = {}
	o.peripheral = peripheral.wrap(peripheralName)
	setmetatable(o, self)
	self.__index = self
	return o
end

local TableHelper = {}
TableHelper.getIndex = function(searchTable, searchValue)
	for i, value in pairs(searchTable) do
		if value == searchValue then
			return i
		end
	end
	return nil
end
TableHelper.contains = function(searchTable, searchValue)
	return TableHelper.getIndex(searchTable, searchValue) ~= nil
end

--## Variables to track state ##--
m.combineStacksForCapacity = false
m.blacklistFile = "blacklist.blist"
m.fuelListDir = "" --can move to sub dir here if need be
m.fuelListFile = "fuel.flist"
m.chestDir = ""
m.cinputFile = "input.clist"
m.coutputFile = "output.clist"

m.fuelList = {} -- whitelist of fuels
m.blacklist = {} -- unsmeltables
m.furnaces = {} -- all furnaces in an array
m.chests = {} -- all chests in an array
m.inputs = {} -- subset of chests designated as input
m.outputs = {} -- subset of chests designated as output

m.furnaceStack = FurnaceStack:new() -- available furnaces
m._taskStack = {}

m._timerID = nil -- main loop
m._furnaceTimers = {} -- index is timerID, value is furnace itself
m._pollRate = 7 -- seconds

--## Helper Functions ##--

m.isFuel = function(self, name)
	return self.fuelList[name] ~= nil
end

m.fuelTier = function(self, name)
	if self.fuelList[name] ~= nil then
		return self.fuelList[name]
	end
	return 0
end

m.checkForBlacklist = function(self)
	if fs.exists(self.fuelListDir .. self.blacklistFile) then
		local handle = fs.open(self.fuelListDir .. self.blacklistFile, "r")
		if handle ~= nil then
			local blacklistText = handle.readAll() or ""
			self.blacklist = textutils.unserialize(blacklistText)
			handle.close()
		end
	else
		self.blacklist = {}
		self:saveBlacklist()
	end
end

m.saveBlacklist = function(self)
	if self.fuelListDir ~= "" and not fs.exists(self.fuelListDir) then
		fs.makeDir(self.fuelListDir)
	end

	local handle = fs.open(self.fuelListDir .. self.blacklistFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.blacklist))
		handle.close()
	end
end

m.checkForFuelList = function(self)
	if fs.exists(self.fuelListDir .. self.fuelListFile) then
		local handle = fs.open(self.fuelListDir .. self.fuelListFile, "r")
		if handle ~= nil then
			local fuelListText = handle.readAll() or ""
			self.fuelList = textutils.unserialize(fuelListText)
			handle.close()
		end
	end
end

m.saveFuelList = function(self)
	if self.fuelListDir ~= "" and not fs.exists(self.fuelListDir) then
		fs.makeDir(self.fuelListDir)
	end

	local handle = fs.open(self.fuelListDir .. self.fuelListFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.fuelList))
		handle.close()
	end
end

m.register = function(self)
	term.clear()
	term.setCursorPos(1, 1)

	local fuelItems = {}
	for _, furnace in pairs(self.furnaces) do
		local fuelItem = furnace.peripheral.list()[furnace.fuelSlot]
		if fuelItem ~= nil then
			fuelItems[#fuelItems + 1] = fuelItem.name
		end
	end

	for _, fuelName in ipairs(fuelItems) do
		if self.fuelList[fuelName] == nil then
			print("How many items can this smelt?\n" .. fuelName)
			self.fuelList[fuelName] = tonumber(read())
		end
	end
end

m.getPeripherals = function(self)
	for _, pName in ipairs(peripheral.getNames()) do
		if string.find(pName, "chest") then
			local chest = peripheral.wrap(pName)
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
					self.chests[#self.chests + 1] = pName
					break
				end
			end
		end
	end
end

m.hasChestsAssigned = function(self) -- wraps the peripherals
	local chestPath = self.chestDir

	if fs.exists(chestPath .. self.cinputFile) then
		local handle = fs.open(chestPath .. self.cinputFile, "r")
		if handle ~= nil then
			local inputListText = handle.readAll() or ""
			local inputListUnserialized = textutils.unserialize(inputListText)
			if type(inputListUnserialized) == "table" then
				self.inputs = inputListUnserialized
			end
			handle.close()
		end
	end

	if fs.exists(chestPath .. self.coutputFile) then
		local handle = fs.open(chestPath .. self.coutputFile, "r")
		if handle ~= nil then
			local outputListText = handle.readAll() or ""
			local outputListUnserialized = textutils.unserialize(outputListText)
			if type(outputListUnserialized) == "table" then
				self.outputs = outputListUnserialized
			end
			handle.close()
		end
	end

	for i, v in ipairs(self.inputs) do
		self.inputs[i] = peripheral.wrap(v)
	end
	for i, v in ipairs(self.outputs) do
		self.outputs[i] = peripheral.wrap(v)
	end

	return #self.chests == #self.inputs + #self.outputs
end

m.assignChests = function(self)
	local chests = {}
	for _, pName in ipairs(peripheral.getNames()) do
		if string.find(pName, "chest") then
			table.insert(chests, pName)
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
					table.insert(chests, pName)
					break
				end
			end
		end
	end
	local assigner = filterassigner:new(chests, { "Input", "Output", "Filter" })
	local assignments = assigner:run(term.native())
	error(assignments)
	for k, v in pairs(assignments) do
		if k == "Input" then
			self.inputs = v
		elseif k == "Output" then
			self.outputs = v
		elseif k == "Filter" then
			self.filters = v
		end
	end

	if self.chestDir ~= "" and not fs.exists(self.chestDir) then
		fs.makeDir(self.chestDir)
	end

	local handle = fs.open(self.chestDir .. self.cinputFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.inputs))
		handle.close()
	end

	handle = fs.open(self.chestDir .. self.coutputFile, "w")
	if handle ~= nil then
		handle.write(textutils.serialize(self.outputs))
		handle.close()
	end
end

m.checkFurnaces = function(self)
	for _, furnace in pairs(self.furnaces) do
		self:checkFurnace(furnace)
	end
end

m.checkFurnace = function(self, furnace)
	local inputItem = furnace.peripheral.list()[furnace.inputSlot]
	if inputItem ~= nil then
		local newTimer = os.startTimer((10 * inputItem.count) + 0.5)
		self._furnaceTimers[newTimer] = furnace
	else
		for _, chest in ipairs(self.outputs) do
			furnace.peripheral.pushItems(peripheral.getName(chest), furnace.fuelSlot)
			furnace.peripheral.pushItems(peripheral.getName(chest), furnace.outputSlot)
		end
		self.furnaceStack:push(furnace)
		os.queueEvent("timer_furnaceavailable")
	end
end

m.pushItemsToOutput = function(self, originPeriph, slot)
	local itemsToPush = originPeriph.getItemDetail(slot).count
	for _, oChest in ipairs(self.outputs) do
		itemsToPush = itemsToPush - originPeriph.pushItems(peripheral.getName(oChest), slot)
		if itemsToPush == 0 then
			break
		end
	end
end

m.mapInventory = function(self) --separate inventory in input
	local items = {} -- items with fuel removed as an unsorted array, with name, count, slot and chest captured
	local fuels = {} -- fuels indexed by their fuel amount (sparce table), with the value being an array of all the fuels that match with their slot
	local fuelTiers = {} -- array in reverse sort of the different fuel levels, to be used in conjunction with {fuels}

	for _, chest in ipairs(self.inputs) do
		for slot, data in pairs(chest.list()) do
			local item = { name = data.name, count = data.count, pos = slot, chest = chest }
			if self.blacklist[item.name] then
				self:pushItemsToOutput(item.chest, item.pos)
			elseif self:isFuel(item.name) then
				local tier = self:fuelTier(item.name)
				if fuels[tier] == nil then
					fuels[tier] = {}
				end
				fuels[tier][#fuels[tier] + 1] = item

				local addedTier = false
				for i = 1, #fuelTiers do -- add tiers in ascending order
					-- tier will run into list in ascending, so if it's less than index 2, it by default is less
					-- than index > 2. we add at the earliest point we can
					if tier == fuelTiers[i] then
						addedTier = true
						break
					elseif tier < fuelTiers[i] then
						table.insert(fuelTiers, i, tier)
						addedTier = true
						break
					end
				end
				if not addedTier then -- assuming tier is > everything in the list
					fuelTiers[#fuelTiers + 1] = tier
				end
			else
				items[#items + 1] = item
			end
		end
	end
	return { items = items, fuels = fuels, fuelTiers = fuelTiers }
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

m.prioritizeFuels = function(self, fuels) --re-sort list of fuels for each tier
	for _, fuelList in pairs(fuels) do
		table.sort(fuelList, self._sortByStackCountAsc)
	end
end

m.canSmelt = function(_, items, fuels, fuelTiers)
	if #items > 0 then
		for _, item in ipairs(items) do
			if math.floor(item.count / fuelTiers[1]) > 0 then
				for _, fuelTier in ipairs(fuelTiers) do
					for _, fuel in ipairs(fuels[fuelTier]) do
						if fuel.count * fuelTier >= 1 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

m.getNextSmeltBundle = function(self, items, fuels, fuelTiers)
	local item = items[1]
	for i = #fuelTiers, 1, -1 do
		local fuelTier = fuelTiers[i]
		local quantityNeeded = 1
		while (fuelTier * quantityNeeded) % 1 ~= 0 do
			quantityNeeded = quantityNeeded + 1
		end
		for j = #fuels[fuelTier], 1, -1 do
			local fuel = fuels[fuelTier][j]
			if fuel.count >= quantityNeeded and item.count >= fuelTier * quantityNeeded then
				local fuelToUse = quantityNeeded
				local itemsToSmelt = fuelTier * fuelToUse
				if self.combineStacksForCapacity then
					for k = quantityNeeded, fuel.count, quantityNeeded do
						if item.count >= fuelTier * k then
							fuelToUse = k
							itemsToSmelt = fuelTier * k
						else
							break
						end
					end
				end
				item.count = item.count - itemsToSmelt
				fuel.count = fuel.count - fuelToUse

				if item.count == 0 then
					table.remove(items, 1)
					self:prioritizeItems(items)
				end
				if fuel.count == 0 then
					table.remove(fuels[fuelTier], j)
					self:prioritizeFuels(fuels)
				end

				return { item = item, fuel = fuel, itemAmount = itemsToSmelt, fuelAmount = fuelToUse }
			end
		end
	end
end

m.smeltFromQueue = function(_, item, itemAmount, fuel, fuelAmount, furnace)
	local itemsAdded = furnace:addItem(item.chest, item.pos, itemAmount)
	local fuelAdded = furnace:addFuel(fuel.chest, fuel.pos, fuelAmount)
	if itemsAdded == nil or itemsAdded == 0 then
		return false
	end
	if fuelAdded == nil or fuelAdded == 0 then
		return false
	end
	return true
end

m.processInventory = function(self, mappedInventory)
	local items = mappedInventory.items
	local fuels = mappedInventory.fuels
	local fuelTiers = mappedInventory.fuelTiers

	self:prioritizeItems(items)
	self:prioritizeFuels(fuels)

	while not self.furnaceStack:isEmpty() and self:canSmelt(items, fuels, fuelTiers) do
		local furnace = self.furnaceStack:peek()
		local smeltBundle = self:getNextSmeltBundle(items, fuels, fuelTiers)
		if smeltBundle == nil then
			break
		end
		local item = smeltBundle.item
		local fuel = smeltBundle.fuel
		local itemAmount = smeltBundle.itemAmount
		local fuelAmount = smeltBundle.fuelAmount
		local success = self:smeltFromQueue(item, itemAmount, fuel, fuelAmount, furnace)
		if success then
			local timeAmount = 10
			-- if (string.find(peripheral.getName(furnace.peripheral), "blast_furnace")) then
			--   timeAmount = 5
			-- end
			self.furnaceStack:pop()
			os.queueEvent("timer_furnaceloaded", (timeAmount * itemAmount) + 0.5, furnace.index)
		else
			--			self.blacklist[item.name] = true
			--			self:saveBlacklist()
			self:pushItemsToOutput(furnace.peripheral, 1)
			self:pushItemsToOutput(furnace.peripheral, 2)
			break
		end
	end
end

m.removeFurnace = function(self, furnaceName)
	self.furnaces[furnaceName] = nil
	for i, furnace in ipairs(self.furnaceStack.stack) do
		if peripheral.getName(furnace.peripheral) == furnaceName then
			self.furnaceStack:remove(i)
			break
		end
	end
	for k, furnace in pairs(self._furnaceTimers) do
		if furnace.index == furnaceName then
			self._furnaceTimers[k] = nil
			os.cancelTimer(k)
			break
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

m.run = function(self)
	term.clear()
	term.setCursorPos(1, 1)
	print("Sorter is running.")
	self._timerID = os.startTimer(0)
	for _ = 1, #self.furnaceStack.stack, 1 do
		os.queueEvent("timer_furnaceavailable")
	end

	parallel.waitForAny(function()
		self:checkTimers()
	end, function()
		self:processTasks()
	end)
end

--## Constructor Method ##--

m.new = function(self) -- , t)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	--self.t = t
	return o
end

--return m

--## Main Runtime ##--

os.setComputerLabel("Smelter " .. os.computerID())

if args[1] == "run" then
	smelter = m:new()
	smelter:getPeripherals()
	smelter:checkForFuelList()
	while not smelter:hasChestsAssigned() do
		smelter:assignChests()
	end
	smelter:checkFurnaces()
	smelter:run()
elseif args[1] == "register" then
	smelter = m:new()
	smelter:getPeripherals()
	smelter:checkForFuelList()
	smelter:register()
	smelter:saveFuelList()
elseif args[1] == "test" then
	sorter = m:new()
	-- smelter:getPeripherals()
	-- smelter:checkForFuelList()
	-- while not sorter:hasChestsAssigned() do
	sorter:assignChests()
	-- end
end
