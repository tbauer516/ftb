local m = {}

m._state = -1
m._fcolorOn = colors.white
m._fcolorOff = colors.white
m._bcolorOn = colors.green
m._bcolorOff = colors.red
m._bcolorStatic = colors.blue
m._bcolorInProgress = colors.lightGray
m._ui = nil
m._x = nil
m._y = nil
m._w = nil
m._h = nil
m._label = nil
m.type = "interact"
m._timerID = nil

--## Private Functions

m._toggle = function(self)
  self._state = self._state * -1
end

m._buildUI = function(self, win)
  local w, h = win.getSize()

  local numLines = math.ceil(#self._label / (w - 2))

  local ui = {}
  
  local empty = ""
  for i = 1,w do
    empty = empty .. " "
  end

  local index = 1
  for i = 1,numLines do
    if (index > #self._label) then break end
    local row = string.sub(self._label, index, index + w - 3)
    if (#row < w - 2) then
      for j = 1,math.floor(((w - 2) - #row) / 2) do
        row = " " .. row
      end
      for j = 1,(w - 2) - #row do
        row = row .. " "
      end
    end
    row = " " .. row .. " "
    ui[#ui + 1] = row
    index = index + w - 2
  end

  for i = 1,math.floor((h - #ui) / 2) do
    table.insert(ui, empty)
  end
  for i = 1, h - #ui do
    table.insert(ui, 1, empty)
  end
  self._ui = ui
end

m._displayInProgress = function(self, win)
  self:_buildUI(win)
  win.setCursorPos(1, 1)

  win.setTextColor(self._fcolorOn)
  win.setBackgroundColor(self._bcolorInProgress)
  for i = 1, #self._ui do
    win.write(self._ui[i])
    win.setCursorPos(1, 1 + i)
  end
end

m._displayToggle = function(self, win)
  self:_buildUI(win)
  local newFColor = self._fcolorOff
  local newBColor = self._bcolorOff
  if (self._state == 1) then
    newFColor = self._fcolorOn
    newBColor = self._bcolorOn
  end

  win.setCursorPos(1, 1)

  win.setTextColor(newFColor)
  win.setBackgroundColor(newBColor)
  for i = 1, #self._ui do
    win.write(self._ui[i])
    win.setCursorPos(1, 1 + i)
  end
end

m._displayStatic = function(self, win)
  self:_buildUI(win)
  win.setCursorPos(1, 1)
  
  -- win.setTextColor(self._fcolorOff)
  -- win.setBackgroundColor(self._bcolorOff)
  -- for i = 1, #self._ui do
  --   win.write(self._ui[i])
  --   win.setCursorPos(1, 1 + i)
  -- end

  -- wait(1)
  -- win.setCursorPos(1, 1)

  win.setTextColor(self._fcolorOn)
  win.setBackgroundColor(self._bcolorStatic)
  for i = 1, #self._ui do
    win.write(self._ui[i])
    win.setCursorPos(1, 1 + i)
  end
end

m._clickToggle = function(self, func, ...)
  local args = {...}
  self:_toggle()
  func(unpack(args))
end

m._clickStatic = function(self, func, ...)
  local args = {...}
  func(unpack(args))
end

--## Public Functions

m.getState = function(self)
  if (self._state == 1) then
    return true
  else
    return false
  end
end

m.setClick = function(self, func, ...)
  local args = {...}
  self.click = function(self)
    self:clickArgs(func, args)
  end
end

m.click = nil

m.clickArgs = nil

m.display = nil

m.displayStart = nil

--## Constructor ##--

--Common
m.new = function(_, label)
  local o = {}
  setmetatable(o, { __index = m })
  o._label = label
  return o
end

m.newToggle = function(_, x, y, w, h, label)
  local o = m:new(x, y, w, h, label)
  setmetatable(o, { __index = m })
  o.clickArgs = o._clickToggle
  o.display = o._displayToggle
  o.displayStart = o._displayInProgress
  return o
end

m.newStatic = function(_, x, y, w, h, label)
  local o = m:new(x, y, w, h, label)
  setmetatable(o, { __index = m })
  o.clickArgs = o._clickStatic
  o.display = o._displayStatic
  o.displayStart = o._displayInProgress
  return o
end

return m