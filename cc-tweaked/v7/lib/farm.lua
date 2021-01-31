local m = {}

--## Variables to track state ##--
m.t = nil -- placeholder for "t" module to go

m.timerID = nil
m.delay = 20

--## Helper Functions ##--

m.initFuel = function(self, minFuel)
  term.clear()
  term.setCursorPos(1,1)
  if (turtle.getFuelLevel() < minFuel) then
    turtle.select(self:getEmpty())
    while (turtle.getFuelLevel() < minFuel) do
      turtle.suckDown(1)
      turtle.refuel()
    end
  end
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
    else
      if (new[k][2] > old[k][2]) then
        diffs[#diffs + 1] = k
      end
    end
  end
  return diffs
end

m.getEmpty = function(self)
  for i=1,16 do
    if (turtle.getItemCount(i) == 0) then
      return i
    end
  end
  return nil
end

--## Run Functions ##--

m.farmBlock = function(self)
  turtle.select(1)
  if (turtle.detect()) then
    self.t:mineF()
  else
    self.t:moveF()
    local data = {turtle.inspectDown()}
    if (data[2] and data[2].state and data[2].state.age == 7) then
      local old = self:getInventory()
      self.t:digD()
      local diffs = self:getInventoryDiff(old, self:getInventory())
      for i,v in ipairs(diffs) do
        turtle.select(v)
        if (turtle.placeDown()) then
          break
        end
      end
    end
  end
end

m.scanFarm = function(self)
  self.t:moveU()
  self.t:moveF()
  self:farmBlock()
  self.t:moveL()
  for i=1,4 do
    self:farmBlock()
  end
  self.t:moveR()
  local dirW = 1
  local length = 7
  for i=1,9 do
    if (i == 1 or i > 5) then
      length = 7
    else
      length = 6
    end
    for j=1,length do
      self:farmBlock()
    end
    if (i ~= 9) then
      self.t:turnTo(self.t:getLoc().d + dirW)
      self:farmBlock()
      self.t:turnTo(self.t:getLoc().d + dirW)
      dirW = dirW * -1
    end
  end
  self:farmBlock()
  self.t:moveL()
  for i=1,8 do
    self:farmBlock()
  end
  self.t:moveL()
  for i=1,8 do
    self:farmBlock()
  end
  self.t:moveL()
  for i=1,4 do
    self:farmBlock()
  end
  self.t:moveL()
  self.t:moveB()
  self.t:moveB()
  self.t:moveD()
end

m.depositItems = function(self)
  self.t:moveR()
  for i=1,16 do
    if (turtle.getItemCount(i) > 0) then
      turtle.select(i)
      turtle.drop()
    end
  end
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

--## Runtime Logic ##--

m.run = function(self)
  self:checkRunStatus("left")

  while true do
    self:initFuel(100)
    self:scanFarm()
    self:depositItems()
    self:setDelay()
    self:checkRunStatus("left")
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
