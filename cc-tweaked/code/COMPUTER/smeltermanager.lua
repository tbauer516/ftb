local listassigner = require("ui/listassigner")

local args = { ... }
if (#args < 1) then -- or #args > 1) then
  print("Computer will manage an input chest, output chest and any number of furnaces.")
  print("Register a fuel source with 'smeltermanager register' and input how much fuel it provides.")
  print("You will have to place a row of water source block on the right and left side from back to front.")
  print()
  print("usage: smeltermanager <register or run>")
  error()
end

--## Program Globals ##--

local smelter = nil -- placeholder for instance

--## Module ##--

local m = {}

--## Variables to track state ##--
m.fuelListDir = "" --can move to sub dir here if need be
m.fuelListFile = "fuel.flist"
m.chestDir = ""
m.cinputFile = "input.clist"
m.coutputFile = "output.clist"

m.fuelList = {} -- whitelist of fuels
m.furnaces = {} -- all furnaces in an array
m.chests = {}   -- all chests in an array
m.inputs = {}   -- subset of chests designated as input
m.outputs = {}  -- subset of chests designated as output

m.furnaceStack = {}

m._timerID = nil
m._furnaceTimers = {}
m._pollRate = 10 -- seconds

--## Helper Functions ##--

m.isFuel = function(self, name)
  return self.fuelList[name] ~= nil
end

m.fuelTier = function(self, name)
  if (self.fuelList[name] ~= nil) then
    return self.fuelList[name]
  end
  return 0
end

m.checkForFuelList = function(self)
  local flistPath = self.fuelListDir
  
  if (fs.exists(flistPath .. self.fuelListFile)) then
    local handle = fs.open(flistPath .. self.fuelListFile, "r")
    local fuelListText = handle.readAll()
    self.fuelList = textutils.unserialize(fuelListText)
    handle.close()
  end
end

m.saveFuelList = function(self)
  if (self.fuelListDir ~= "" and not fs.exists(self.fuelListDir)) then
    fs.makeDir(self.fuelListDir)
  end
    
  local handle = fs.open(self.fuelListDir .. self.fuelListFile, "w")
  handle.write(textutils.serialize(self.fuelList))
  handle.close()
end

m.register = function(self)
  term.clear()
  term.setCursorPos(1,1)

  local fuelItems = {}
  for i, furnace in ipairs(self.furnaces) do
    local fuelItem = furnace.list()[2]
    if (fuelItem ~= nil) then
      fuelItems[#fuelItems + 1] = fuelItem.name
    end
  end

  for i, fuelName in ipairs(fuelItems) do
    if (self.fuelList[fuelName] == nil) then
      print("How many items can this smelt?\n" .. fuelName)
      self.fuelList[fuelName] = tonumber(read())
    end
  end
end

m.getPeripherals = function(self)
  for k,v in ipairs(peripheral.getNames()) do
    if (string.find(v, "furnace")) then
      local furnace = peripheral.wrap(v)
      furnace.isAvailable = function(self)
        return self.list()[1] == nil and self.list()[2] == nil
      end
      furnace.addFuel = function(self, inputChest, slot, limit)
        return self.pullItems(peripheral.getName(inputChest), slot, limit, 2)
      end
      furnace.addItem = function(self, inputChest, slot, limit)
        return self.pullItems(peripheral.getName(inputChest), slot, limit, 1)
      end
      furnace.emptySmeltToOutput = function(self, outputChest)
        return self.pushItems(peripheral.getName(outputChest), 3)
      end
      furnace.emptySmelt = function(self, outputChests)
        local itemGrabbedCount = 0
        for i, chest in ipairs(outputChests) do
          if (self.list()[3] == nil) then
            break
          end
          itemGrabbedCount = itemGrabbedCount + self:emptySmeltToOutput(chest)
        end
        return itemGrabbedCount
      end
      self.furnaces[#self.furnaces + 1] = furnace
      self.furnaceStack[#self.furnaceStack + 1] = furnace
    elseif (string.find(v, "chest")) then  
      self.chests[#self.chests + 1] = v
    end
  end
end

m.hasChestsAssigned = function(self) -- wraps the peripherals
  local chestPath = self.chestDir
  
  if (fs.exists(chestPath .. self.cinputFile)) then
    local handle = fs.open(chestPath .. self.cinputFile, "r")
    local inputListText = handle.readAll()
    self.inputs = textutils.unserialize(inputListText)
    handle.close()
  end

  if (fs.exists(chestPath .. self.coutputFile)) then
    local handle = fs.open(chestPath .. self.coutputFile, "r")
    local outputListText = handle.readAll()
    self.outputs = textutils.unserialize(outputListText)
    handle.close()
  end

  for i,v in ipairs(self.inputs) do
    self.inputs[i] = peripheral.wrap(v)
  end
  for i,v in ipairs(self.outputs) do
    self.outputs[i] = peripheral.wrap(v)
  end

  return #self.chests == #self.inputs + #self.outputs
end

m.assignChests = function(self)
  local assigner = listassigner:new(self.chests, {"Input", "Output"})
  local assignments = assigner:run(term.native())
  for k,v in pairs(assignments) do
    if (k == "Input") then
      self.inputs = v
    elseif(k == "Output") then
      self.outputs = v
    end
  end

  if (self.chestDir ~= "" and not fs.exists(self.chestDir)) then
    fs.makeDir(self.chestDir)
  end

  local handle = fs.open(self.chestDir .. self.cinputFile, "w")
  handle.write(textutils.serialize(self.inputs))
  handle.close()

  local handle = fs.open(self.chestDir .. self.coutputFile, "w")
  handle.write(textutils.serialize(self.outputs))
  handle.close()
end

m.mapInventory = function(self) --separate inventory in input
  local items = {} -- items with fuel removed as an unsorted array, with name, count, slot and chest captured
  local fuels = {} -- fuels indexed by their fuel amount (sparce table), with the value being an array of all the fuels that match with their slot
  local fuelTiers = {} -- array in reverse sort of the different fuel levels, to be used in conjunction with {fuels}
  for chesti, chest in ipairs(self.inputs) do
    for slot, data in pairs(chest.list()) do
      local item = {name = data.name, count = data.count, pos = slot, chest = chest}
      if (self:isFuel(data.name)) then
        local tier = self:fuelTier(data.name)
        if (fuels[tier] == nil) then
          fuels[tier] = {}
        end
        fuels[tier][#fuels[tier] + 1] = item

        local addedTier = false
        for i = 1, #fuelTiers do -- add tiers in ascending order
          -- tier will run into list in ascending, so if it's less than index 2, it by default is less
          -- than index > 2. we add at the earliest point we can
          if (tier == fuelTiers[i]) then
            addedTier = true
            break
          elseif (tier < fuelTiers[i]) then
            table.insert(fuelTiers, i, tier)
            addedTier = true
            break
          end
        end
        if (not addedTier) then -- assuming tier is > everything in the list
          fuelTiers[#fuelTiers + 1] = tier
        end
      else
        items[#items + 1] = item
      end
    end
  end
  return {items = items, fuels = fuels, fuelTiers = fuelTiers}
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
  for tier, fuelList in pairs(fuels) do
    table.sort(fuelList, self._sortByStackCountAsc)
  end
end

m.queueSmelt = function(self, items, fuels, fuelTiers) --assign items and fuel to furnaces
  local itemIndex = 1
  
  for furnaceIndex = #self.furnaceStack, 1, -1 do
    local furnace = self.furnaceStack[#self.furnaceStack]
    if (items[itemIndex] == nil) then
      break
    elseif (furnace:isAvailable()) then
      for i = #fuelTiers, 1, -1 do -- go through fuels in descending order by amount they can smelt
        local fuelTier = fuelTiers[i]
        local maxFuelNeeded = math.floor(items[itemIndex].count / fuelTier)
        if (maxFuelNeeded > 0) then
          local actualFuelAvailable = math.min(fuels[fuelTier][#fuels[fuelTier]].count, maxFuelNeeded) -- assumes more items than fuels
          local itemsPerFuelAvailable = math.floor(actualFuelAvailable * fuelTier)
          actualFuelAvailable = math.floor(itemsPerFuelAvailable / fuelTier)
          local itemsAdded = furnace:addItem(items[itemIndex].chest, items[itemIndex].pos, itemsPerFuelAvailable)
          if (itemsAdded == 0) then
            itemIndex = itemIndex + 1
          else
            self.furnaceStack[#self.furnaceStack] = nil
            furnace:addFuel(fuels[fuelTier][#fuels[fuelTier]].chest, fuels[fuelTier][#fuels[fuelTier]].pos, actualFuelAvailable)
            local newTimer = os.startTimer((10 * itemsAdded) + 1)
            self._furnaceTimers[newTimer] = furnace
            items[itemIndex].count = items[itemIndex].count - itemsPerFuelAvailable
            fuels[fuelTier][#fuels[fuelTier]].count = fuels[fuelTier][#fuels[fuelTier]].count - actualFuelAvailable -- reduce count by used
            
            if (items[itemIndex].count == 0) then
              itemIndex = itemIndex + 1
            end
            if (fuels[fuelTier][#fuels[fuelTier]].count == 0) then -- exhaust stack of fuel
              table.remove(fuels[fuelTier], #fuels[fuelTier]) -- remove fuel from list and allow to move to next in list
              if (#fuels[fuelTier] == 0) then -- ran out of fuel tier
                table.remove(fuelTiers, i)
              end
            end
          end
        end
      end
    end
  end
end

m.processInventory = function(self)
  local mappedInventory = self:mapInventory()
  local items = mappedInventory.items
  local fuels = mappedInventory.fuels
  local fuelTiers = mappedInventory.fuelTiers

  self:prioritizeItems(items)
  self:prioritizeFuels(fuels)

  self:queueSmelt(items, fuels, fuelTiers)
end

m.processEvents = function(self, event)
  if (event[1] == "timer" and event[2] == self._timerID) then
    print("Timer " .. event[2] .. " processed")
    self._timerID = os.startTimer(self._pollRate)
    if (#self.furnaceStack > 0) then
      self:processInventory()
    end
  elseif (event[1] == "timer") then
    local furnace = self._furnaceTimers[event[2]]
    print("Furnace " .. peripheral.getName(furnace) .. " finished")
    self._furnaceTimers[event[2]] = nil
    furnace:emptySmelt(self.outputs)
    self.furnaceStack[#self.furnaceStack + 1] = furnace
    self:processInventory()
  elseif (event[1] == "key" and event[2] == keys.delete) then
    os.cancelTimer(self._timerID)

    term.clear()
    term.setCursorPos(1,1)

    error("Manually cancelled operation")
  end
end

m.run = function(self)
  term.clear()
  term.setCursorPos(1,1)
  self._timerID = os.startTimer(0)
  
  while true do
    local event = {os.pullEvent()}
    self:processEvents(event)
  end
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

if (args[1] == "run") then
  smelter = m:new()
  smelter:getPeripherals()
  smelter:checkForFuelList()
  while (not smelter:hasChestsAssigned()) do
    smelter:assignChests()
  end
  smelter:run()
elseif (args[1] == "register") then
  smelter = m:new()
  smelter:getPeripherals()
  smelter:checkForFuelList()
  smelter:register()
  smelter:saveFuelList()
elseif (args[1] == "test") then
  smelter = m:new()
  smelter:getPeripherals()
  smelter:checkForFuelList()
  while (not smelter:hasChestsAssigned()) do
    smelter:assignChests()
  end
end
