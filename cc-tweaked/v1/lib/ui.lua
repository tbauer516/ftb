local m = {}

m._elements = {}
m._timerID = nil

--## Private  Functions

m.processEvents = function(self, event)
  if (event[1] == "timer") then
    self:_update()

    self._timerID = os.startTimer(3)
  elseif (event[1] == "mouse_click") then
    self:click(event[3], event[4])
  elseif (event[1] == "monitor_touch") then
    self:click(event[3], event[4])
  elseif (event[1] == "key" and event[2] == keys.delete) then
    os.cancelTimer(self._timerID)

    for i = 1, #self._elements do
      local e = self._elements[i].e
      local m = self._elements[i].m
      m.clear()
      m.setCursorPos(1,1)
    end
    term.clear()
    term.setCursorPos(1,1)

    error()
  end
end

function wait(time)
  local timer = os.startTimer(time)

  while true do
    local event = {os.pullEvent()}

    if (event[1] == "timer" and event[2] == timer) then
      break
    else
      m:processEvents(event) -- a custom function in which you would deal with received events
    end
  end
end

m._update = function(self)
  for i = 1, #self._elements do
    local e = self._elements[i].e
    local m = self._elements[i].m
    if (e.update ~= nil) then
      e:update()
      e:display(m)
    end
  end
end

--## Public Functions

m.add = function(self, el, mon)
  self._elements[#self._elements + 1] = {e = el, m = mon}
end

m.click = function(self, x, y)
  for i = 1, #self._elements do
    local e = self._elements[i].e
    local m = self._elements[i].m
    if (e.click ~= nil) then
      local pos = e:getPos()
      if (x >= pos.x and x <= pos.x + pos.w - 1 and y >= pos.y and y <= pos.y + pos.h - 1) then
        e:click()
        e:display(m)
      end
    end
  end
end

m.displayAll = function(self)
  for i = 1, #self._elements do
    local el = self._elements[i].e
    local mon = self._elements[i].m
    el:display(mon)
  end
end

m.display = function(self, el)
  for i = 1, #self._elements do
    local e = self._elements[i].e
    local m = self._elements[i].m
    if (e == el) then
      e:display(m)
    end
  end
end

m.run = function(self)
  self:displayAll()

  self._timerID = os.startTimer(0)
  
  while true do
    local event = {os.pullEvent()}
    self:processEvents(event)
  end
end

--## Constructor ##--

m.new = function(_)
  local o = {}
  setmetatable(o, { __index = m })
  return o
end

return m