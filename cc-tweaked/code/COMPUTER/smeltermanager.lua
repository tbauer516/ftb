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

m.furnaces = {}
m.chests = {}

m.fuelItem = nil
m.fuelSlot = 16
m.fuelLimit = 10

m.saplingItem = nil
m.saplingSlot = nil

m.timerID = nil
m.delay = 20

--## Helper Functions ##--

m.checkForFuelList = function(self, fuelList)
  local flistPath = self.fuelListDir
  if (fs.exists("disk/")) then
    flistPath = "disk/" .. flistPath
  end
  local handle = nil
  if (fuelList ~= nil) then
    if (fs.exists(flistPath .. fuelList .. ".flist")) then
      handle = fs.open(flistPath .. fuelList .. ".flist", "r")
    end
  else
    if (fs.exists(flistPath .. "default.flist")) then
      handle = fs.open(flistPath .. "default.flist", "r")
    end
  end
  if (handle ~= nil) then
    local fuelListText = handle.readAll()
    self.fuelList = textutils.unserialize(fuelListText)
    handle.close()
  end
end

m.saveFuelList = function(self, fuelData)
  if (self.fuelListDir ~= "" and not fs.exists(self.fuelListDir)) then
    fs.makeDir(self.fuelListDir)
  end
  
  if (fs.exists(self.fuelListDir .. "fuel.flist")) then
    local handle = fs.open(self.fuelListDir .. "fuel.flist", "r")
    local fuelListText = handle.readAll()
    local fuelList = textutils.unserialize(fuelListText)
    handle.close()
    for k,v in pairs(fuelData) do
      fuelList[k] = v
    end
  end
  
  local handle = fs.open(self.fuelListDir .. "fuel.flist", "w")
  handle.write(textutils.serialize(fuelList))
  handle.close()
end

m.register = function(self)
  term.clear()
  term.setCursorPos(1,1)
end

m.getFurnaces = function(self)
  for k,v in ipairs(peripheral.getNames()) do
    if (string.find(v, "furnace")) then
      self.furnaces[#self.furnaces + 1] = v
    elseif (string.find(v, "chest")) then  
      self.chests[#self.chests + 1] = v
    end
  end
  print(textutils.serialize(self.furnaces))
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
  smelter:run()
elseif (args[1] == "register") then
  
end
