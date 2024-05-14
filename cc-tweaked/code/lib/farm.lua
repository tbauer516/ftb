local m = {}

--## Variables to track state ##--
m.t = nil -- placeholder for "t" module to go

m.timerID = nil
m.delay = 20 * 60
m.minFuel = 350

--## Helper Functions ##--

m.initFuel = function(self, minFuel)
  term.clear()
  term.setCursorPos(1,1)
  if (turtle.getFuelLevel() < minFuel) then
    turtle.select(self.t:getEmptySlot())
    while (turtle.getFuelLevel() < minFuel) do
      turtle.suckDown(1)
      turtle.refuel()
    end
  end
end

--## Run Functions ##--

m.farmBlock = function(self)
  turtle.select(1)
  if (turtle.detect()) then
    self.t:moveU()
    if (turtle.detect()) then
      self.t:digF()
    end
    self.t:moveD()
    self.t:mineF()
  else
    self.t:moveF()
    local data = {turtle.inspectDown()}
    if (data[2] and data[2].state and (data[2].state.age == 7 or (data.name == "minecraft:beetroots" and data.state.age == 3))) then
      local old = self.t:getInventory()
      self.t:digD()
      local diffs = self.t:getInventoryDiff(old, self.t:getInventory())
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

--## Runtime Logic ##--

m.run = function(self)
  self.t:checkRunStatus("left")

  while true do
    self:initFuel(self.minFuel)
    self:scanFarm()
    self:depositItems()
    self.t:setDelay(20 * 60)
    self.t:checkRunStatus("left")
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
