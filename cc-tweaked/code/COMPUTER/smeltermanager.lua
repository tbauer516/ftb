local ui = require("ui/uimanager"):new()
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

m.fuelList = {}
m.furnaces = {}
m.chests = {}
m.inputs = {}
m.outputs = {}

m.timerID = nil
m.delay = 20

--## Helper Functions ##--

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

m.getPeripherals = function(self)
  for k,v in ipairs(peripheral.getNames()) do
    if (string.find(v, "furnace")) then
      self.furnaces[#self.furnaces + 1] = v
    elseif (string.find(v, "chest")) then  
      self.chests[#self.chests + 1] = v
    end
  end
end

m.run = function(self)
  -- self.t:checkRunStatus("left")

  -- while true do
  --   self:initRun()
  --   self:setSaplingType()
  --   self:moveFromHomeToFirstTree()
  --   self:scanFarm()
  --   self:scoopItems()
  --   self:depositItems()
  --   -- self.t:checkRunStatus("left")
  --   self.t:setDelay(20 * 60)
  --   self.t:checkRunStatus("left")
  -- end
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
end
