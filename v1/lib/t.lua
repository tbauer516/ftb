local m = {}

--## Variables to track state ##--

m.fuelSlot = 16

--x is forward/backward plane from initial position with + = forward and - = backward
--y is elevation and increases as turtle goes down, think of it like depth, + = down and - = up
--z is left/right plane from initial position with + = right and - = left
--d is direction, 0/2 is x plane, 1/3 is z plane
m.curLoc = {x = 0, y = 0, z = 0, d = 0}
m.maxLoc = {x = 0, y = 0, z = 0, d = 0}
m.homeLoc = {x = 0, y = 0, z = 0, d = 0} -- does not change, for easy use

m.fuelReserve = 100

--## Helper Functions ##--

m.moveHelper = function(self, attack, move)
  local count = 1
  local moveSuccess = move()
  while (not moveSuccess) do
    attack()
    if (count >= 10) then
      return false
    end
    count = count + 1
    moveSuccess = move()
  end
  return true
end

--## Public Functions ##--

m.calcLocU = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"] - dist, z = self.curLoc["z"], d = self.curLoc["d"]}
end
m.calcLocD = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"] + dist, z = self.curLoc["z"], d = self.curLoc["d"]}
end
m.calcLocF = function(self, dist)
  if (self.curLoc["d"] == 0) then
    return {x = self.curLoc["x"] + dist, y = self.curLoc["y"], z = self.curLoc["z"], d = self.curLoc["d"]}
  elseif (self.curLoc["d"] == 1) then
    return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"] + dist, d = self.curLoc["d"]}
  elseif (self.curLoc["d"] == 2) then
    return {x = self.curLoc["x"] - dist, y = self.curLoc["y"], z = self.curLoc["z"], d = self.curLoc["d"]}
  elseif (self.curLoc["d"] == 3) then
    return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"] - dist, d = self.curLoc["d"]}
  end
end
m.calcLocB = function(self, dist)
  if (self.curLoc["d"] == 0) then
    return {x = self.curLoc["x"] - dist, y = self.curLoc["y"], z = self.curLoc["z"], d = self.curLoc["d"]}
  elseif (curLoc["d"] == 1) then
    return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"] - dist, d = self.curLoc["d"]}
  elseif (self.curLoc["d"] == 2) then
    return {x = self.curLoc["x"] + dist, y = self.curLoc["y"], z = self.curLoc["z"], d = self.curLoc["d"]}
  elseif (self.curLoc["d"] == 3) then
    return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"] + dist, d = self.curLoc["d"]}
  end
end
m.calcLocR = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"], d = (self.curLoc["d"] + dist) % 4}
end
m.calcLocL = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"], z = self.curLoc["z"], d = (self.curLoc["d"] - dist) % 4}
end

m.getLocString = function(self, loc)
  return "{"..loc["x"]..","..loc["y"]..","..loc["z"]..","..loc["d"].."}"
end

m.copyLoc = function(self, target)
  return {x = target["x"], y = target["y"], z = target["z"], d = target["d"]}
end

m.getLoc = function(self)
  return self:copyLoc(self.curLoc)
end

m.printLoc = function(self, target)
  for k, v in pairs(target) do
    print(k .. ": " .. v)
  end
end

m.calcDist = function(self, target)
  return math.abs(self.curLoc["x"] - target["x"]) + math.abs(self.curLoc["y"] - target["y"]) + math.abs(self.curLoc["z"] - target["z"])
end

m.checkFuel = function(self, targetLoc)
  local dist = self:calcDist(targetLoc) + 20
  if (turtle.getFuelLevel() <= dist) then
    turtle.select(self.fuelSlot)
    while (turtle.getFuelLevel() <= dist) do
      if (turtle.getItemCount(self.fuelSlot) < 5) then
        error("Out of fuel in slot")
      end
      turtle.refuel(1)
    end
  end
end

m.moveU = function(self)
  local newLoc = self:calcLocU(1)
  local success = self:moveHelper(turtle.attackUp, turtle.up)
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveD = function(self)
  local newLoc = self:calcLocD(1)
  local success = self:moveHelper(turtle.attackDown, turtle.down)
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveF = function(self)
  local newLoc = self:calcLocF(1)
  local success = self:moveHelper(turtle.attack, turtle.forward)
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveB = function(self)
  local newLoc = self:calcLocB(1)
  local success = self:moveHelper(turtle.attack,  turtle.back)
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveR = function(self)
  local newLoc = self:calcLocR(1)
  local success = turtle.turnRight()
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveL = function(self)
  local newLoc = self:calcLocL(1)
  local success = turtle.turnLeft()
  if (success) then
    self.curLoc = newLoc
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end

m.digU = function(self)
  return turtle.digUp()
end
m.digD = function(self)
  return turtle.digDown()
end
m.digF = function(self)
  while (turtle.detect()) do
    if (turtle.dig()) then
      sleep(.1)
    else
      return false
    end
  end
  return true
end

m.mineU = function(self)
  if (turtle.detectUp()) then
    if (not self:digU()) then
      error("Unable to dig up")
    end
  end
  return self:moveU()
end
m.mineD = function(self)
  if (turtle.detectDown()) then
    if (not self:digD()) then
      error("Unable to dig down")
    end
  end
  return self:moveD()
end
m.mineF = function(self)
  if (turtle.detect()) then
    if (not self:digF()) then
      error("Unable to dig forward")
    end
  end
  return self:moveF()
end

m.turnTo = function(self, dir)
  if (self.curLoc["d"] == (dir + 2) % 4) then -- dir is 180 from cur
    self:moveR()
    self:moveR()
  elseif (self.curLoc["d"] == (dir + 3) % 4) then -- dir is 90 to right of cur
    self:moveR()
  elseif (self.curLoc["d"] == (dir + 1) % 4) then -- dir is 90 to left of cur
    self:moveL()
  end
end

m.moveTo = function(self, targetLoc)
  --adjust elevation to match
  if (self.curLoc["y"] > targetLoc["y"]) then
    while (self.curLoc["y"] ~= targetLoc["y"]) do
      self:mineU()
    end
  elseif (self.curLoc["y"] < targetLoc["y"]) then
    while (self.curLoc["y"] ~= targetLoc["y"]) do
      self:mineD()
    end
  end

  --turn along z axis towards center (facing plane x = 0)
  if (self.curLoc["z"] ~= targetLoc["z"]) then
    local unitDir = (self.curLoc["z"] - targetLoc["z"]) / math.abs(self.curLoc["z"] - targetLoc["z"]) -- -1 or 1
    local goal = unitDir + 2 -- 1 or 3
    self:turnTo(goal)
    while (self.curLoc["z"] ~= targetLoc["z"]) do
      self:mineF()
    end
  end

  --turn along x axis towards center (facing plane z = 0)
  if (self.curLoc["x"] ~= targetLoc["x"]) then
    local unitDir = (self.curLoc["x"] - targetLoc["x"]) / math.abs(self.curLoc["x"] - targetLoc["x"]) -- -1 or 1
    local goal = unitDir + 1 -- 0 or 2
    self:turnTo(goal)
    while (self.curLoc["x"] ~= targetLoc["x"]) do
      self:mineF()
    end
  end

  self:turnTo(targetLoc["d"])
end

--## Constructor Method ##--

m.new = function(self)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

return m