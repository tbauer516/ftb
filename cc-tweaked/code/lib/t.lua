local m = {}

m.n = nil -- placeholder for networking module

m.globalBlacklist = {
  "computer"
}

--## Variables to track state ##--

m.fuelSlot = 16

--x is forward/backward plane from initial position with + = forward and - = backward
--y is elevation and increases as turtle goes down, think of it like depth, + = down and - = up
--z is left/right plane from initial position with + = right and - = left
--d is direction, 0/2 is x plane, 1/3 is z plane. 0 is East, increasing as we go clockwise (i.e. 1 is South)
m.curLoc = {x = 0, y = 0, z = 0, d = 0}
m.maxLoc = {x = 0, y = 0, z = 0, d = 0}
m.homeLoc = {x = 0, y = 0, z = 0, d = 0} -- does not change, for easy use
m.cruiseAltitude = 0
m.status = "Idle"

m.fuelReserve = 100

m.delayTimerID = nil

--## Helper Functions ##--

--## Mining Helpers ##--

m.shouldDig = function(self, inspectFunc)
  for i=1,50 do
    local success, data = inspectFunc()
    if (type(data) ~= "table") then
      return true
    end
    local foundBlacklist = false
    for i,v in ipairs(self.globalBlacklist) do
      if (string.find(data.name, v)) then
        foundBlacklist = true
      end
    end
    if (not foundBlacklist) then
      return true
    end
    sleep(.2)
  end
  return false
end

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
  if (self.n and self.n:checkModem()) then
    self:sendLoc()
  end
  return true
end

--## Networking Helpers ##--

m.setLoc = function(self, newLoc)
  self.curLoc = newLoc
end

m.sendLoc = function(self)
  local loc = self:getLoc()
  loc.s = self.status
  self.n:sendLoc(loc)
end

m.setCruise = function(self, newCruise)
  self.cruiseAltitude = newCruise
end

m.setStatus = function(self, newStatus)
  self.status = newStatus
end

m.findDir = function(self)
  if (self.n:checkGPS()) then
    if (turtle.getFuelLevel() < 2) then
      error("Please add fuel before beginning")
    end

    local trapped = false
    local dirOffset = 0
    local result = {gps.locate()}
    local result2 = nil
    if (turtle.back()) then
      result2 = result
      result = {gps.locate()}
      turtle.forward()
    elseif (turtle.forward()) then
      result2 = {gps.locate()}
      turtle.back()
    else
      dirOffset = 1
      turtle.turnLeft()
      if (turtle.back()) then
        result2 = result
        result = {gps.locate()}
        turtle.forward()
      elseif (turtle.forward()) then
        result2 = {gps.locate()}
        turtle.back()
      else
        trapped = true
      end
      turtle.turnRight()
    end

    if (trapped) then error("Turtle is trapped!") end

    local dir = nil
    if (result2[1] > result[1]) then -- moved east
      dir = 0
    elseif (result2[1] < result[1]) then -- moved west
      dir = 2
    elseif (result2[3] > result[3]) then -- moved south
      dir = 1
    elseif (result2[3] < result[3]) then -- moved north
      dir = 3
    end
    return (dir + dirOffset) % 4
  end
end

m.setLocFromGPS = function(self)
  if (self.n:checkGPS()) then
    local loc = {gps.locate()}
    local dir = self:findDir()
    local newLoc = {x = loc[1], y = loc[2], z = loc[3], d = dir}
    self:setLoc(self:copyLoc(newLoc))
    self.homeLoc = self:copyLoc(newLoc)
  else
    error("No GPS detected")
  end
end

--## Runtime Helpers ##--

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

m.checkRunStatus = function(self, side)
  local baseTime = os.clock()
  while true do
    if (redstone.getInput(side)) then
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

m.setDelay = function(self, delayTime)
  self.timerID = os.startTimer(delayTime)
  sleep(2)
  local result = nil
  local baseTime = os.clock()
  os.startTimer(1)
  while true do
    result = {os.pullEvent()}
    if (result[1] == "timer" and result[2] == self.delayTimerID) then
      break
    else
      term.clear()
      term.setCursorPos(1,1)
      local currentTime = os.clock()
      local remaining = (delayTime) - (currentTime - baseTime)
      term.write("Remaining: " .. math.floor(remaining / 60) .. "m " .. math.floor(remaining % 60) .. "s")
      os.startTimer(1)
    end
  end
  term.clear()
  term.setCursorPos(1,1)
end

--## Inventory Helpers ##--

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
    else
      if (new[k][2] > old[k][2]) then
        diffs[#diffs + 1] = k
      end
    end
  end
  return diffs
end

m.getEmptySlot = function(self)
  for i=1,16 do
    if (turtle.getItemCount(i) == 0) then
      return i
    end
  end
  return nil
end

--## Public Functions ##--

--## Location Functions ##--

m.calcLocU = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"] + dist, z = self.curLoc["z"], d = self.curLoc["d"]}
end
m.calcLocD = function(self, dist)
  return {x = self.curLoc["x"], y = self.curLoc["y"] - dist, z = self.curLoc["z"], d = self.curLoc["d"]}
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
  elseif (self.curLoc["d"] == 1) then
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

m.moveU = function(self)
  local newLoc = self:calcLocU(1)
  local success = self:moveHelper(turtle.attackUp, turtle.up)
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveD = function(self)
  local newLoc = self:calcLocD(1)
  local success = self:moveHelper(turtle.attackDown, turtle.down)
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveF = function(self)
  local newLoc = self:calcLocF(1)
  local success = self:moveHelper(turtle.attack, turtle.forward)
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveB = function(self)
  local newLoc = self:calcLocB(1)
  local success = self:moveHelper(turtle.attackUp, turtle.back)
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveR = function(self)
  local newLoc = self:calcLocR(1)
  local success = turtle.turnRight()
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end
m.moveL = function(self)
  local newLoc = self:calcLocL(1)
  local success = turtle.turnLeft()
  if (success) then
    self:setLoc(newLoc)
  else
    error("Unable to move to" .. self:getLocString(newLoc))
  end
  return success
end

m.digU = function(self)
  if (self:shouldDig(turtle.inspectUp) and turtle.detectUp()) then
    return turtle.digUp()
  end
  return false
end
m.digD = function(self)
  if (self:shouldDig(turtle.inspectDown) and turtle.detectDown()) then
    return turtle.digDown()
  end
  return false
end
m.digF = function(self)
  while (turtle.detect()) do
    if (not self:shouldDig(turtle.inspect)) then
      return false
    end
    if (turtle.detect()) then
      if (turtle.dig()) then
        sleep(.1)
      else
        return false
      end
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
      self:mineD()
    end
  elseif (self.curLoc["y"] < targetLoc["y"]) then
    while (self.curLoc["y"] ~= targetLoc["y"]) do
      self:mineU()
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

m.cruiseTo = function(self, targetLoc)
  self:checkFuel(targetLoc, math.abs(self.curLoc.y - self.cruiseAltitude) + math.abs(self.cruiseAltitude - targetLoc.y))

  local highBeginning = self:getLoc()
  highBeginning.y = self.cruiseAltitude
  self:moveTo(highBeginning)

  local highTarget = self:copyLoc(targetLoc)
  highTarget.y = self.cruiseAltitude
  self:moveTo(highTarget)
  self:moveTo(targetLoc)
end

--## Fuel Helpers ##--

m.checkFuel = function(self, targetLoc, buffer)
  if (buffer == nil) then buffer = 0 end
  local dist = self:calcDist(targetLoc) + 20 + buffer
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

--## Constructor Method ##--

m.new = function(self, n)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  self.n = n
  return o
end

return m