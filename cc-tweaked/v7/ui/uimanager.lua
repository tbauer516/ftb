local m = {}

m._monitors = {}  -- maps {monitors -> {elements -> windows}}}
m._elements = {}  -- maps {elements -> {windows}}
m._computerName = "comp"
m._timerID = nil
m._validTypes = {
  "interact",
  "non-interact",
}

--## Private  Functions

m.processEvents = function(self, event)
  if (event[1] == "timer" and event[2] == self._timerID) then
    self:_update()

    self._timerID = os.startTimer(3)
  elseif (event[1] == "mouse_click") then
    self:_click(event[3], event[4], self._computerName)
  elseif (event[1] == "monitor_touch") then
    self:_click(event[3], event[4], event[2])
  elseif (event[1] == "key" and event[2] == keys.delete) then
    os.cancelTimer(self._timerID)

    for k,v in pairs(self._monitors) do
      if (k ~= self._computerName) then
        peripheral.call(k, "clear")
        peripheral.call(k, "setCursorPos", 1, 1)
      end
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
  for e,wins in pairs(self._elements) do
    if (e.update ~= nil) then
      e:update()
      self:display(e)
    end
  end
end

m._click = function(self, x, y, mon)
  for e,wins in pairs(self._monitors[mon]) do
    if (e.click ~= nil) then
      for i,win in ipairs(wins) do
        local winX, winY = win.getPosition()
        local winW, winH = win.getSize()
        if (x >= winX and x <= winX + winW -1 and y >= winY and y <= winY + winH - 1) then
          if (e.displayStart) then
            self:displayStart(e)
          end
          e:click()
          self:display(e)
        end
      end
    end
  end
end

m._checkElementsAreValid = function(self)
  for e,wins in pairs(self._elements) do
    if (e.update == nil and e.click == nil) then
      error("1 or more elements do not have a 'click' or 'update' method")
    end
    if (e.type == nil) then
      error("missing the 'type' field that specifies what type of UI element this is")
    else
      local valid = false
      for i,v in ipairs(self._validTypes) do
        if (e.type == v) then
          valid = true
        end
      end
      if (not valid) then
        error("invalid 'type' field found for UI element")
      end
    end
  end
end

--## Public Functions ##--

--[[
  el:      the element created
  x,y,w,h: the position and size of the element on that monitor
  [mon]:   the string that represents the monitor that will be wrapped as a peripheral (i.e. "left", "monitor_0")
]]
m.add = function(self, el, x, y, w, h, mon)
  if (mon == nil) then mon = self._computerName end
  local periph
  if (mon == self._computerName) then
    periph = term.native()
  else
    periph = peripheral.wrap(mon)
  end
  local win = window.create(periph, x, y, w, h)

  if (self._monitors[mon] == nil) then
    self._monitors[mon] = {}
  end
  if (self._monitors[mon][el] == nil) then
    self._monitors[mon][el] = {}
  end
  if (self._elements[el] == nil) then
    self._elements[el] = {}
  end

  self._monitors[mon][el][#self._monitors[mon][el] + 1] = win
  self._elements[el][#self._elements[el] + 1] = win
end

m.displayAll = function(self)
  local renders = {}
  for el,wins in pairs(self._elements) do
    for i,win in ipairs(wins) do
      renders[#renders + 1] = function() el:display(win) end
    end
  end
  parallel.waitForAll(unpack(renders))
end

m.display = function(self, el)
  local renders = {}
  for i,win in ipairs(self._elements[el]) do
    renders[#renders + 1] = function() el:display(win) end
  end
  parallel.waitForAll(unpack(renders))
end

m.displayStart = function(self, el)
  local renders = {}
  for i,win in ipairs(self._elements[el]) do
    renders[#renders + 1] = function() el:displayStart(win) end
  end
  parallel.waitForAll(unpack(renders))
end

m.run = function(self)
  self:_checkElementsAreValid()

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