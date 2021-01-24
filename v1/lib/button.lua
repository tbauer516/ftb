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
m._func = nil
m._funcArgs = nil
m.type = "interact"

--## Private Functions

m._toggle = function(self)
  self._state = self._state * -1
end

m._buildUI = function(self)
  local ui = {}

  local empty = ""
  for i = 1,self._w do
    empty = empty .. " "
  end

  local text = ""
  for i = 1,math.ceil((self._w - string.len(self._label)) / 2) do
    text = text .. " "
  end
  text = text .. self._label
  for i = 1,math.floor((self._w - string.len(self._label)) / 2) do
    text = text .. " "
  end

  for i = 1, self._h do
    if (i == math.ceil(self._h / 2)) then
      ui[#ui + 1] = text
    else
      ui[#ui + 1] = empty
    end
  end
  self._ui = ui
end

m._displayToggle = function(self, mon)
  local oldFColor = mon.getTextColor()
  local oldBColor = mon.getBackgroundColor()
  local newFColor = self._fcolorOff
  if (self._state == 1) then
    newFColor = self._fcolorOn
  end
  local newBColor = self._bcolorOff
  if (self._state == 1) then
    newBColor = self._bcolorOn
  end

  mon.setCursorPos(self._x, self._y)

  mon.setTextColor(newFColor)
  mon.setBackgroundColor(newBColor)
  for i = 1, #self._ui do
    mon.write(self._ui[i])
    mon.setCursorPos(self._x, self._y + i)
  end

  mon.setTextColor(colors.white)
  mon.setBackgroundColor(colors.black)
end

m._displayStatic = function(self, mon)
  local oldFColor = mon.getTextColor()
  local oldBColor = mon.getBackgroundColor()
  
  mon.setCursorPos(self._x, self._y)

  mon.setTextColor(self._fcolorOff)
  mon.setBackgroundColor(self._bcolorOff)
  for i = 1, #self._ui do
    mon.write(self._ui[i])
    mon.setCursorPos(self._x, self._y + i)
  end

  --wait(0.1)
  mon.setCursorPos(self._x, self._y)

  mon.setTextColor(self._fcolorOn)
  mon.setBackgroundColor(self._bcolorOn)
  for i = 1, #self._ui do
    mon.write(self._ui[i])
    mon.setCursorPos(self._x, self._y + i)
  end

  mon.setTextColor(colors.white)
  mon.setBackgroundColor(colors.black)
end

m._clickArgsToggle = function(self, func, ...)
  local args = {...}
  self:_toggle()
  func(unpack(args))
end

m._clickArgsStatic = function(self, func, ...)
  local args = {...}
  func(unpack(args))
end

--## Public Functions

m.getPos = function(self)
  return {x = self._x, y = self._y, w = self._w, h = self._h}
end

m.setClick = function(self, func, ...)
  local args = {...}
  self._func = func
  self._funcArgs = args
end

m.click = function(self)
  self:clickArgs(self._func, unpack(self._funcArgs))
end

m.clickArgs = nil

m.display = nil

--## Constructor ##--

--Common
m.new = function(_, x, y, w, h, label)
  local o = {}
  setmetatable(o, { __index = m })
  -- self.__index = m
  o._x = x
  o._y = y
  o._w = w
  o._h = h
  o._label = label
  o:_buildUI()
  return o
end

m.newToggle = function(_, x, y, w, h, label)
  local o = m:new(x, y, w, h, label)
  setmetatable(o, { __index = m })
  o.type = "toggle"
  o.clickArgs = o._clickArgsToggle
  o.display = o._displayToggle
  return o
end

m.newStatic = function(_, x, y, w, h, label)
  local o = m:new(x, y, w, h, label)
  setmetatable(o, { __index = m })
  o.type = "static"
  o.clickArgs = o._clickArgsStatic
  o.display = o._displayStatic
  return o
end

return m