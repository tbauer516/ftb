local m = {}

--## Variables to track state ##--
m.t = nil -- placeholder for "t" module to go


m.bedrockDangerZone = 5
m.surfaceBuffer = 5
m.junkSlot = 15
m.junkLimit = 10

m.bedrockLoc = nil
m.blacklist = {}

m.quarryLength = 1
m.quarryWidth = 1

m.blocksMined = 0

m.initialLoc = nil
m.locFile = "initial.loc"

--## Helper Functions ##--

m.setQuarrySize = function(self, length, width)
  self.quarryLength = length
  self.quarryWidth = width
end

m.checkForBlacklist = function(self, blacklistName)
  local blistPath = "blacklist/"
  if (fs.exists("disk/")) then
    blistPath = "disk/" .. blistPath
  end
  if (blacklistName ~= nil) then
    if (fs.exists(blistPath .. blacklistName .. ".blist")) then
      local handle = fs.open(blistPath .. blacklistName .. ".blist", "r")
      local blacklistText = handle.readAll()
      self.blacklist = textutils.unserialize(blacklistText)
      handle.close()
    end
  else
    if (fs.exists(blistPath .. "default.blist")) then
      local handle = fs.open(blistPath .. "default.blist", "r")
      local blacklistText = handle.readAll()
      self.blacklist = textutils.unserialize(blacklistText)
      handle.close()
    end
  end
end

-- check if it's an inventory. if yes, we suck until either it's empty, or we're out of room
-- if it's empty, we have room, or it's not an inventory, we return "true" which means "mine it"
-- if it is an inventory and we run out of room, return 'false' which means "don't mine it"
m.suckHelper = function(self, side, suckFunc)
  local types = {peripheral.getType(side)}
  if (types == nil) then return true end

  for i = #types, 1, -1 do
    if (types[i] == "inventory") then
      local emptySlot = self.t:getEmptySlot()
      turtle.select(self.junkSlot)
      while (emptySlot ~= nil and #peripheral.call(side, "list") > 0) do
        while (suckFunc()) do end
        if (side == "top" or side == "front") then
          self:consolidate()
        else
          self:consolidateDropDir(turtle.drop)
        end
        emptySlot = self.t:getEmptySlot()
      end
      if (emptySlot ~= nil and #peripheral.call(side, "list") == 0) then -- have room and chest empty
        return true
      else
        return false
      end
    end
  end
  return true
end

m.scanHelper = function(self, detectFunc, inspectFunc)
  if (detectFunc()) then
    local success, data = inspectFunc()
    for i = 1, #self.blacklist do
      if (self.blacklist[i] == data["name"]) then
        return false
      end
    end
    return true
  end
end

--## Public Functions ##--

m.scanU = function(self)
  if (self:scanHelper(turtle.detectUp, turtle.inspectUp)) then
    return true
  end
  return false
end
m.scanD = function(self)
  if (self:scanHelper(turtle.detectDown, turtle.inspectDown)) then
    return true
  end
  return false
end
m.scanF = function(self)
  if (self:scanHelper(turtle.detect, turtle.inspect)) then
    return true
  end
  return false
end

m.suckU = function(self)
  if (self:suckHelper("top", turtle.suckUp)) then
    return true
  end
  return false
end
m.suckD = function(self)
  if (self:suckHelper("bottom", turtle.suckDown)) then
    return true
  end
  return false
end
m.suckF = function(self)
  if (self:suckHelper("front", turtle.suck)) then
    return true
  end
  return false
end

m.mineBedrockColumn = function(self)
  local columnTop = self.t:getLoc()
  local success, value = pcall(function()
    while (true) do
      while (not self:suckF()) do
        self:checkStorage()
      end
      if (self:scanF()) then
        self.t:digF()
      end
      while (not self:suckD()) do
        self:checkStorage()
      end
      self.t:mineD()
    end
  end)
  self.t:moveTo(columnTop)
end

m.burrow = function(self)
  self.t:mineD()
  self.t:mineD()
  turtle.select(self.junkSlot)
  turtle.placeUp()

  local success, value = pcall(function()
    while (true) do
      while (not self:suckD()) do
        self:consolidate()
        if (self:storageFull()) then
          local burrowLoc = self.t:getLoc()
          self.t:moveTo(self.initialLoc)
          self:dumpItems()
          self.t:mineD()
          self.t:mineD()
          turtle.select(self.junkSlot)
          turtle.placeUp()
          self.t:moveTo(burrowLoc)
        end
      end
      self.t:mineD()
    end
  end)
  self.bedrockLoc = self.t:getLoc()
  self.bedrockLoc.y = self.bedrockLoc.y + self.bedrockDangerZone
  self.t:moveTo(self.bedrockLoc)
end

-- don't want to hit anything on the way up
-- move back 1 in case chest above/below, move down a level
-- move to column of start, then move up
m.returnToSurface = function(self)
  self.t:setStatus("Returning to surface")
  turtle.select(self.junkSlot)
  self.t.maxLoc = self.t:getLoc()
  local vertical = self.t:copyLoc(self.bedrockLoc)
  if (self.t:getLoc().y < self.initialLoc.y - self.surfaceBuffer) then
    vertical.y = math.max(self.bedrockLoc.y, self.t.maxLoc.y - 3)
  else
    vertical.y = self.t:getLoc().y
  end
  self.t:checkFuel(self.t.homeLoc)
  self.t:moveTo(vertical)

  self.t:moveTo(self.initialLoc)
  
  turtle.select(self.junkSlot)
  turtle.placeDown()
  turtle.select(self.junkSlot)
  
  self.t:setStatus("Moving to home")
  self.t:cruiseTo(self.t.homeLoc)
end

m.returnToMine = function(self)
  self.t:setStatus("Returning to mine location")
  self.t:cruiseTo(self.initialLoc)

  turtle.select(self.junkSlot)
  self.t:mineD()
  self.t:mineD()
  turtle.select(self.junkSlot)
  turtle.placeUp()

  self.t:checkFuel(self.t.maxLoc)
  local vertical = self.t:copyLoc(self.bedrockLoc)
  vertical.y = math.max(self.bedrockLoc.y, self.t.maxLoc.y - 3)
  self.t:moveTo(vertical)
  
  self.t:setStatus("Tunneling to previous location")
  local belowMaxLoc = self.t:copyLoc(self.t.maxLoc)
  belowMaxLoc.y = vertical.y
  belowMaxLoc.d = vertical.d
  self.t:moveTo(belowMaxLoc)
  self.t:moveTo(self.t.maxLoc)
  self.t:setStatus("Mining")
end

m.consolidateDropDir = function(self, dropFunc)
  for i = 1, self.junkSlot - 1 do
    local details = turtle.getItemDetail(i)
    if (details ~= nil) then
      for j = 1, #self.blacklist do
        if (details["name"] == self.blacklist[j]) then
          turtle.select(i)
          dropFunc()
        end
      end
      if (turtle.getItemCount(i) > 0) then
        turtle.transferTo(self.t.fuelSlot)
      end
    end
  end
  local count = turtle.getItemCount(self.junkSlot)
  if (count > self.junkLimit) then
    turtle.select(self.junkSlot)
    dropFunc(count - self.junkLimit)
  end
  turtle.select(self.junkSlot)
end

m.consolidate = function(self)
  self:consolidateDropDir(turtle.dropDown)
end

m.dumpItems = function(self)
  self:consolidate()
  for i = 1, self.junkSlot - 1 do
    turtle.select(i)
    self.blocksMined = self.blocksMined + turtle.getItemCount()
    turtle.drop()
  end
  turtle.select(self.junkSlot)
end

m.storageFull = function(self)
  return turtle.getItemCount(self.junkSlot - 1) > 0
end

m.checkStorage = function(self)
  if (self:storageFull()) then
    self:returnToSurface()
    self:dumpItems()
    self:returnToMine()
  end
end

--## Runtime Logic ##--

m.start = function(self)
  self.t:setStatus("Mining")
  local starttime = os.clock()
  local quarrysuccess, quarryvalue = pcall(function()

    self.t:checkFuel(self.t:calcLocD(300))
    self:burrow() -- gets us to bedrock + dangerzone
  
    local initialD = self.t:getLoc().d
    local wDir = 1
    
    if (self.bedrockDangerZone > 0) then -- do bedrock pattern across plane and back to end up in initial position
      for planeI = 1, 2 do -- do the plane one direction, then do it again the other direction
        for rowI = 1, self.quarryWidth do -- inside this loop == done once per row
          for cellI = 1, self.quarryLength - 1 do -- inside this loop == done once per cell
            self:consolidate()
            self:mineBedrockColumn()
            while (not self:suckF()) do
              self:checkStorage()
            end
            self.t:mineF()
          end

          if (rowI < self.quarryWidth) then -- on every row but the last, turn around on the new row
            local originalDir = self.t:getLoc()
            self.t:turnTo((initialD + wDir) % 4)
            self:consolidate()
            self:mineBedrockColumn()
            while (not self:suckF()) do
              self:checkStorage()
            end
            self.t:mineF()
            self.t:turnTo((originalDir.d + 2) % 4)
            self.t:checkFuel(self.t.homeLoc)
            self:checkStorage()
          end
        end

        self.t:turnTo((self.t:getLoc().d + 2) % 4)
        wDir = wDir * -1
      end
    end

    while (true) do -- inside this loop == done once per level
  
      for rowI = 1, self.quarryWidth do -- inside this loop == done once per row
        self:consolidate()
  
        for cellI = 1, self.quarryLength - 1 do -- inside this loop == done once per cell
          while (not self:suckF()) do
            self:checkStorage()
          end
          self.t:mineF()
          while (not self:suckU()) do self:checkStorage() end
          if (self:scanU()) then self.t:digU() end
          while (not self:suckD()) do
            self.t:moveB()
            self:checkStorage()
            self.t:moveF()
          end
          if (self:scanD()) then self.t:digD() end
          self.t:checkFuel(self.t.homeLoc)
          turtle.select(self.junkSlot)
          self:checkStorage()
        end
  
        if (rowI < self.quarryWidth) then -- on every row but the last, turn around on the new row
          local originalDir = self.t:getLoc()
          self.t:turnTo((initialD + wDir) % 4)
          while (not self:suckF()) do
            self:checkStorage()
          end
          self.t:mineF()
          while (not self:suckU()) do self:checkStorage() end
          if (self:scanU()) then self.t:digU() end
          while (not self:suckD()) do
            self.t:moveB()
            self:checkStorage()
            self.t:moveF()
          end
          if (self:scanD()) then self.t:digD() end
          self.t:turnTo((originalDir.d + 2) % 4)
          self.t:checkFuel(self.t.homeLoc)
          self:checkStorage()
        end
      end
      
      -- move up a level
      if (self.t:getLoc().y < self.initialLoc.y - self.surfaceBuffer) then -- if not at the top
        self.t:moveR()
        self.t:moveR()
        while (not self:suckU()) do self:checkStorage() end
        self.t:mineU()
        while (not self:suckU()) do self:checkStorage() end
        self.t:mineU()
        while (not self:suckU()) do self:checkStorage() end
        self.t:mineU()
        while (not self:suckU()) do self:checkStorage() end
        if (self:scanU()) then self.t:digU() end
        wDir = wDir * -1
      else
        break
      end
    end
  end)
  
  if (quarrysuccess) then
    print("Mining completed!")
  else
    print("Could not continue mining!")
    print(quarryvalue)
  end
  
  self:returnToSurface()
  self:dumpItems()
  -- self.t:moveR()
  -- self.t:moveR()
  local endtime = os.clock()
  local mins = math.floor((endtime - starttime) / 60)
  local seconds = math.floor((endtime - starttime) % 60)
  local runtime = mins .. "m " .. seconds .. "s"
  print("Blocks Mined: " .. self.blocksMined)
  print("Runtime: " .. runtime)
  local size = self.quarryLength .. "x" .. self.quarryWidth
  local sizepadded = size
  for i = 1, 7 - #size do
    sizepadded = sizepadded .. " "
  end
  local blockspadded = tostring(self.blocksMined)
  for i = 1, 5 - #tostring(self.blocksMined) do
    blockspadded = blockspadded .. " "
  end
  local h = fs.open("runlog", "a")
  h.writeLine(sizepadded .. blockspadded .. runtime)
  h.close()
end

--## Constructor Method ##--

m.new = function(self, t, l, w, bl)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  self.t = t
  self:setQuarrySize(l, w)
  self:checkForBlacklist(bl)
  self.initialLoc = self.t:getLoc()
  return o
end

return m