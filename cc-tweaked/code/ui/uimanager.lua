local m = {}

m._monitors = {}  -- maps {monitors -> {elements -> windows}}}
m._elements = {}  -- maps {elements -> {windows}}
m._computerName = "comp"
m._timerID = nil
m._validTypes = {
  click = "click",
  scroll = "scroll",
  keyboard = "keyboard",
  displayonly = "update"
}

m._taskQueue = {}

--## Private  Functions

m.performTasks = function(self)
  while (#self._taskQueue > 0) do
    local task = table.remove(self._taskQueue, 1)
    if (task[1] == "timer" and task[2] == self._timerID) then
      self:_update()
      self._timerID = os.startTimer(3)
    elseif (task[1] == "mouse_click") then
      self:_click(task[3], task[4], self._computerName)
    elseif (task[1] == "monitor_touch") then
      self:_click(task[3], task[4], task[2])
    elseif (task[1] == "mouse_scroll") then
      self:_scroll(task[3], task[4], task[2])
    elseif (task[1] == "char") then
      self:_keyboard(task[1], task[2])
    elseif (task[1] == "key") then
      self:_keyboard(task[1], task[2], task[3])
    end
  end
end

m.processEvents = function(self, event)
  if (event[1] == "timer" or event[1] == "mouse_click" or event[1] == "monitor_touch" or event[1] == "mouse_scroll" or event[1] == "char" or event[1] == "key") then
    table.insert(self._taskQueue, event)
    os.queueEvent("ui_task")
  elseif (event[1] == "terminate") then
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
          e:click(win, x, y)
          self:display(e)
        end
      end
    end
  end
end

m._scroll = function(self, x, y, dir)
  for e,wins in pairs(self._monitors[self._computerName]) do
    if (e.scroll ~= nil) then
      for i,win in ipairs(wins) do
        local winX, winY = win.getPosition()
        local winW, winH = win.getSize()
        if (x >= winX and x <= winX + winW -1 and y >= winY and y <= winY + winH - 1) then
          e:scroll(win, dir)
          self:display(e)
        end
      end
    end
  end
end

m._keyboard = function(self, eventName, keyPressed, isHeld)
  for e,wins in pairs(self._monitors[self._computerName]) do
    if (e.keyboard ~= nil) then
      for i,win in ipairs(wins) do
        e:keyboard(eventName, keyPressed, isHeld)
        self:display(e)
      end
    end
  end
end

m._checkElementsAreValid = function(self)
  for e,wins in pairs(self._elements) do
    if (e.type == nil) then
      error("missing the 'type' field that specifies what type of UI element this is")
    else
      local valid = false
      for i, elType in ipairs(e.type) do
        local isTypeInValidList = false
        for typetext, typefunction in pairs(self._validTypes) do
          if (elType == typetext) then
            isTypeInValidList = true
            if (e[typefunction] == nil) then
              error("type " .. typetext .. " requires a function '" .. typefunction .. "' to be present")
            end
          end
        end
        if (not isTypeInValidList) then
          error(elType .. " is not in the valid type list")
        end
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
  
  parallel.waitForAny(
    function()
      while true do
        local event = {os.pullEventRaw()}
        self:processEvents(event)
      end
    end,
    function()
      while true do
        os.pullEvent("ui_task")
        self:performTasks()
      end
    end
  )
end

--## Constructor ##--

m.new = function(_)
  local o = {}
  setmetatable(o, { __index = m })
  return o
end

return m