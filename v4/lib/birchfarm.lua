local m = {}

--## Variables to track state ##--
m.t = nil -- placeholder for "t" module to go

m.fuelItem = nil
m.fuelSlot = 16
m.fuelLimit = 10

m.saplingItem = nil
m.saplingSlot = nil

m.timerID = nil
m.delay = 20

--## Helper Functions ##--

m.setFuelType = function(self)
  local result = turtle.getItemDetail(self.fuelSlot)
  if (result == nil) then
    error("Please add the desired fuel from the farm in slot 16.")
  end
  self.fuelItem = result.name
end

m.setSaplingType = function(self)
  self.t:moveR()
  self.t:moveF()
  for i=1,15 do
    if (turtle.getItemCount(i) == 0) then
      self.saplingSlot = i
      break
    end
  end
  turtle.select(self.saplingSlot)
  turtle.suck(18)
  local itemName = nil
  local itemDetails = turtle.getItemDetail(self.saplingSlot)
  if (itemDetails ~= nil) then
    itemName = itemDetails.name
  end
  self.saplingItem = itemName
  self.t:moveB()
  self.t:moveL()
end

m.initFuel = function(self, minFuel)
  if (turtle.getFuelLevel() < minFuel) then
    while (turtle.getFuelLevel() < minFuel) do
      term.clear()
      term.setCursorPos(1,1)
      print("Please insert any type of fuel in order to get a baseline fuel level.")
      print("Required: " .. minFuel)
      print("Current Fuel Level: " .. turtle.getFuelLevel())
      local oldInventory = self:getInventory()
      local event = {os.pullEvent()}
      if (event[1] == "turtle_inventory") then
        local inventoryDiff = self:getInventoryDiff(oldInventory, self:getInventory())
        for i,v in ipairs(inventoryDiff) do
          turtle.select(v)
          turtle.refuel(64)
        end
      end
    end
  end
  term.clear()
  term.setCursorPos(1,1)
end

m.getInventory = function(self)
  local inventory = {}
  for i=1,16 do
    if (turtle.getItemCount(i) > 0) then
      inventory[i] = {turtle.getItemDetail(i).name, turtle.getItemCount(i)}
    end
  end
  return inventory
end

m.getInventoryDiff = function(self, old, new)
  local diffs = {}
  for k,v in pairs(new) do
    if (old[k] == nil) then
      diffs[#diffs + 1] = k
    end
  end
  return diffs
end

--## Build Functions ##--

m.initBuild = function(self)
  if (turtle.getItemCount(16) == 0 or turtle.getItemCount(1) == 0 or turtle.getItemCount(2) == 0) then
    error("Please add the required items to the turtle inventory. Run 'treefarm' on it's own to see the usage.")
  end

  self:initFuel(400)
end

m.setUpLeft = function(self)
  self.t:mineF()
  self.t:mineD()
  self.t:mineD()
end

m.buildSideTreeHolders = function(self, w) -- starts underground by 2 levels
  local dirW = 1

  for i=1,w do -- width
    for j=1,15 do -- length
      --if (i % 2 == 1 or j % 2 == 1) then
      if ((i==1 or j==1 or j==15) or ((i%4~=3 or j%4~=3) and (i%4~=1 or j%4~=1))) then
        self.t:digU()
      end
      if (j < 15) then
        self.t:mineF()
      else
        self.t:turnTo(self.t:getLoc().d + dirW)
        self.t:mineF()
        self.t:turnTo(self.t:getLoc().d + dirW)
        dirW = dirW * -1
      end
    end
  end
end

m.buildMoveToRightUnderground = function(self)
  self.t:moveL()
  self.t:moveF()
  self.t:moveL()
  self.t:mineF()
  self.t:digU()
  self.t:moveR()
  self.t:moveR()
  self.t:mineD()
  self.t:mineD()
  self.t:mineF()
end

m.buildRightUnderground = function(self)
  local dirW = 1

  for i=1,8 do -- width
    for j=1,15 do -- length
      if (i > 1) then
        self.t:digU()
      end
      if (j < 15) then
        self.t:mineF()
      else
        self.t:turnTo(self.t:getLoc().d + dirW)
        self.t:mineF()
        self.t:turnTo(self.t:getLoc().d + dirW)
        dirW = dirW * -1
      end
    end
  end
end

m.buildMoveToRightAboveGround = function(self)
  self.t:mineU()

  for i=1,7 do
    self.t:mineU()
    self.t:digU()
    self.t:mineF()
    self.t:digU()
    self.t:mineD()
    self.t:digD()
    self.t:mineF()
    self.t:digD()
  end

  self.t:mineU()
  self.t:digU()
  self.t:moveL()
  self.t:mineF()
  self.t:moveL()
end

m.moveToInitialPosition = function(self)
  self.t:moveB()
  self.t:moveU()
  turtle.select(1)
  turtle.placeUp()
  self.t:moveR()
  self.t:digF()
  turtle.select(2)
  turtle.place()
  for i=1,15 do
    turtle.select(i)
    turtle.dropUp()
  end
  self.t:moveR()
  self.t:moveR()
  self.t:mineF()
  self.t:moveR()
end

--## Run Functions ##--

m.initRun = function(self)
  if (turtle.getItemCount(16) == 0) then
    error("Please add the required items to the turtle inventory. Run 'treefarm' on it's own to see the usage.")
  end

  self:setFuelType()
  self:initFuel(200)
end

m.checkFuel = function(self)
  turtle.select(self.fuelSlot)
  while (turtle.getFuelLevel() < 20 and turtle.getItemCount() > 1) do
    turtle.refuel(1)
  end
  if (turtle.getItemCount() == 1) then
    for i=1,15 do
      if (turtle.getItemSpace(self.fuelSlot) > 0 and turtle.getItemDetail(i).name == self.fuelItem) then
        turtle.select(i)
        turtle.transferTo(self.fuelSlot, turtle.getItemSpace(self.fuelSlot))
      end
    end
  end
end

-- m.moveFromHomeToFirstTree = function(self)
--   self.t:mineU()
--   self.t:mineU()
--   self.t:moveL()
--   for i=1,5 do
--     self.t:mineF()
--   end
--   self.t:moveR()
--   self.t:moveF()
-- end

m.moveFromHomeToFirstTree = function(self)
  self.t:mineU()
  self.t:mineU()
  self.t:moveL()
  for i=1,4 do
    self.t:mineF()
  end
  self.t:moveR()
  self.t:moveF()
  self.t:moveF()
end

m.checkIsTree = function(self)
  local success, data = turtle.inspect()
  return success and data.name == self.fuelItem
end

m.checkNeedSapling = function(self)
  if (self.saplingItem and not turtle.detectDown()) then
    turtle.select(self.saplingSlot)
    turtle.placeDown()
  end
end

m.mineTree = function(self)
  local height = 0
  turtle.select(self.fuelSlot)
  self.t:mineF()
  self.t:digD()
  while (turtle.detectUp() and ({turtle.inspectUp()})[2].name == self.fuelItem) do
    self.t:mineU()
    height = height + 1
  end
  while (height > 0) do
    self.t:mineD()
    height = height - 1
  end
end

-- m.scanFarm = function(self)
--   local dirW = 1

--   for i=1,7 do
--     for j=1,7 do
--       self:checkFuel()
--       if (self:checkIsTree()) then
--         self:mineTree()
--       else
--         self.t:mineF()
--       end
--       self:checkNeedSapling()
--       self.t:moveF()
--     end
    
--     if (i < 7) then
--       self.t:turnTo(self.t:getLoc().d + dirW)
--       self.t:mineF()
--       self.t:mineF()
--       self.t:turnTo(self.t:getLoc().d + dirW)
--       dirW = dirW * -1
--     else
--       self.t:moveL()
--       for j=1,5 do
--         self.t:moveD()
--       end
--       for j=1,6 do
--         self.t:moveF()
--       end
--       self.t:moveL()
--     end
--   end
-- end

m.scanFarm = function(self)
  local dirW = 1

  for i=1,6 do
    for j=1,3 do
      self:checkFuel()
      if (self:checkIsTree()) then
        self:mineTree()
      else
        self.t:mineF()
      end
      self:checkNeedSapling()
      for k=1,3 do
        self.t:moveF()
      end
    end
    
    self.t:turnTo(self.t:getLoc().d + dirW)
    self.t:mineF()
    self.t:mineF()
    self.t:turnTo(self.t:getLoc().d + dirW)
    dirW = dirW * -1
  end

  for i=1,13 do
    self:checkFuel()
    self.t:moveF()
  end
  self.t:moveL()
  for j=1,5 do
    self:checkFuel()
    self.t:moveD()
  end
  for j=1,7 do
    self:checkFuel()
    self.t:moveF()
  end
  self.t:moveL()
end

m.scoopItems = function(self)
  for i=1,15 do
    self:checkFuel()
    turtle.suck()
    self.t:moveF()
  end
  for i=1,3 do
    self:checkFuel()
    self.t:moveU()
  end
  self.t:moveL()
end

m.depositItems = function(self)
  turtle.select(self.fuelSlot)
  while (turtle.getFuelLevel() < 200) do
    turtle.refuel(1)
  end

  for i=1,15 do
    if (turtle.getItemCount(i) > 0) then
      turtle.select(i)
      if (turtle.getItemDetail().name == self.saplingItem) then
        turtle.drop()
      elseif (turtle.getItemDetail().name == self.fuelItem and turtle.getItemCount() < 64) then
        turtle.transferTo(self.fuelSlot, turtle.getItemSpace(self.fuelSlot))
        turtle.dropUp()
      else
        turtle.dropUp()
      end
    end
  end
  self.t:moveB()
  self.t:moveL()
end

m.setDelay = function(self)
  self.timerID = os.startTimer(self.delay * 60)
  sleep(2)
  local result = nil
  local baseTime = os.clock()
  os.startTimer(1)
  while true do
    result = {os.pullEvent()}
    if (result[1] == "timer" and result[2] == self.timerID) then
      break
    else
      term.clear()
      term.setCursorPos(1,1)
      local currentTime = os.clock()
      local remaining = (self.delay * 60) - (currentTime - baseTime)
      term.write("Remaining: " .. math.floor(remaining / 60) .. "m " .. math.floor(remaining % 60) .. "s")
      os.startTimer(1)
    end
  end
  term.clear()
  term.setCursorPos(1,1)
end

-- m.checkRunStatus = function(self)
--   if (not redstone.getInput("left")) then
--     error("Redstone signal on left side off. Killing program.")
--   end
-- end

m.checkRunStatus = function(self)
  local baseTime = os.clock()
  while true do
    if (redstone.getInput("left")) then
      break
    end
    term.clear()
    term.setCursorPos(1,1)
    local currentTime = os.clock()
    local elapsed = currentTime - baseTime
    term.write("Elapsed: " .. math.floor(elapsed / 60) .. "m " .. (elapsed % 60) .. "s")
    sleep(5)
  end
  term.clear()
  term.setCursorPos(1,1)
end

--## Runtime Logic ##--

m.build = function(self)
  term.clear()
  term.setCursorPos(1,1)
  self:initBuild()
  self:setUpLeft()
  self:buildSideTreeHolders(8)
  self:buildMoveToRightUnderground()
  self:buildRightUnderground()
  self:buildMoveToRightAboveGround()
  self:buildSideTreeHolders(7)
  self:moveToInitialPosition()
end

m.run = function(self)
  self:checkRunStatus()

  while true do
    self:initRun()
    self:setSaplingType()
    self:moveFromHomeToFirstTree()
    self:scanFarm()
    self:scoopItems()
    self:depositItems()
    -- self:checkRunStatus()
    self:setDelay()
    self:checkRunStatus()
  end
end 

--## Constructor Method ##--

m.new = function(self, t, l, w, bl)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  self.t = t
  return o
end

return m
