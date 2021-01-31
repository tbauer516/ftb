local m = {}

m._state = -1
m._fcolorOn = colors.white
m._fcolorOff = colors.white
m._bcolorOn = colors.green
m._bcolorOff = colors.red
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

  local ui = {}

  local empty = ""
  for i = 1,w do
    empty = empty .. " "
  end

  local text = ""
  for i = 1,math.floor((w - string.len(self._label)) / 2) do
    text = text .. " "
  end
  text = text .. self._label
  local remain = w - #text
  for i = 1,remain do
    text = text .. " "
  end

  for i = 1, h do
    if (i == math.ceil(h / 2)) then
      ui[#ui + 1] = text
    else
      ui[#ui + 1] = empty
    end
  end
  self._ui = ui
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

  win.setTextColor(self._fcolorOff)
  win.setBackgroundColor(self._bcolorOff)
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
  o.type = "toggle"
  o.clickArgs = o._clickToggle
  o.display = o._displayToggle
  return o
end

m.newStatic = function(_, x, y, w, h, label)
  local o = m:new(x, y, w, h, label)
  setmetatable(o, { __index = m })
  o.type = "static"
  o.clickArgs = o._clickStatic
  o.display = o._displayStatic
  return o
end

return m