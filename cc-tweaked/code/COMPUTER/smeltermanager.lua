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

m.fuelList = {}
m.furnaces = {}
m.chests = {}
m.inputs = {}
m.outputs = {}

m.inventory = {} -- should be input chest
m.fuelItems = {} -- should be shortcut to fuel location

m._timerID = nil
m._pollRate = 3000 --ms

--## Helper Functions ##--

m.isFuel = function(self, name)
  for fuelName, fuelAmount in pairs(self.fuelList) do
    if (name == fuelName) then
      return true
    end
  end
  return false
end

m.fuelAmount = function(self, name)
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
  for k,v in ipairs(self.furnaces) do
    local fuelItem = peripheral.call(v, "list")[2]
    if (fuelItem ~= nil) then
      fuelItems[#fuelItems + 1] = fuelItem.name
    end
  end

  for k,v in ipairs(fuelItems) do
    if (self.fuelList[v] == nil) then
      print("How many items can this smelt?\n" .. v)
      self.fuelList[v] = tonumber(read())
    end
  end
end

m._pushToFurnace = function(self, chest, iSlot, furnace, fSlot)
  chest.pushItems(peripheral.getName(furnace), iSlot, chest.getItemDetails(iSlot).maxCount, fSlot)
end

m.pushItemToFurnace = function(self, chest, iSlot, furnace)
  self:_pushToFurnace(chest, iSlot, furnace, 1)
end

m.pushFuelToFurnace = function(self, chest, iSlot, furnace)
  self:_pushToFurnace(chest, iSlot, furnace, 2)
end

--furnace should be empty in slot 1,2 and have no timer
m.isFurnaceAvailable = function(self, furnace)
  return furnace.timerID == nil and furnace.list()[1] == nil and furnace.list()[2] == nil
end

m.getPeripherals = function(self)
  for k,v in ipairs(peripheral.getNames()) do
    if (string.find(v, "furnace")) then
      local furnace = peripheral.wrap(v)
      furnace.isAvailable = function(self)
        return self.timerID == nil and self.list()[1] == nil and self.list()[2] == nil
      end
      self.furnaces[#self.furnaces + 1] = furnace
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
  local items = {}
  local fuel = {}
  for chesti,chest in ipairs(self.inputs) do
    for slot, data in pairs(chest.list()) do
      local item = {"name" = data.name, "count" = data.count, "pos" = slot, "chest" = chest}
      if (self:isFuel(data.name)) then
        local amount = self:fuelAmount(data.name)
        if (fuel[amount] == nil) then
          fuel[amount] = {}
        end
        fuel[amount][#fuel[amount] + 1] = item
      else
        items[#items + 1] = item
      end
    end
  end
  return {"items" = items, "fuels" = fuel}
end

m.prioritizeItems = function(self, items) --re-sort list of items to smelt most important first

  return items
end

m.queueSmelt = function(self, items, fuels) --assign items and fuel to furnaces
  local fuelSizes = {}
  for i, fuel in ipairs(fuels) do

  end

  for i, furnace in ipairs(self.furnaces) do
    if (furnace:isAvailable()) then

    end
  end
end

m.processInventory = function(self)
  local mappedInventory = self:mapInventory()
  local items = mappedInventory.items
  local fuels = mappedInventory.fuels

  items = self:prioritizeItems(items)

  self:queueSmelt(items, fuels)
end

m.processEvents = function(self, event)
  if (event[1] == "timer" and event[2] == self._timerID) then

    self._timerID = os.startTimer(self._pollRate / 1000)
  elseif (event[1] == "timer") then
    for i,furnace in ipairs(self.furnaces) do
      if (furnace.timerID == event[2]) then
        furnace.timerID = nil
      end
    end
  elseif (event[1] == "key" and event[2] == keys.delete) then
    os.cancelTimer(self._timerID)

    term.clear()
    term.setCursorPos(1,1)

    error("Manually cancelled operation")
  end
end

m.run = function(self)
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
