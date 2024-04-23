local m = {}

m._fcolor = colors.white
m._bcolor = colors.black
m._lines = {}
m._scrollpos = 1
m._x = nil
m._y = nil
m._w = nil
m._h = nil
m.type = "interact"

--## Private Functions

m._buildUI = function(self, win)
  local w, h = win.getSize()

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

m._click = function() end

--## Public Functions

m.setClick = function(self, func)
  self._click = func
end

-- determines item clicked, pass it to downstream
m.click = function(self, win, x, y)
  local w, h = win.getSize()
  local winX, winY = win.getPosition()
  win.clear()
  win.setCursorPos(1,1)
  win.write(x .. ", " .. y)
  win.setCursorPos(1,2)
  win.write(self._lines[self._scrollpos + y - winY])
  self._click(self._lines[self._scrollpos + y - winY])
  sleep(3)
end

--dir: -1 is up, 1 is down
m.scroll = function(self, win, dir)
  local w, h = win.getSize()
  if (h >= #self._lines) then
    return
  elseif (dir == -1 and self._scrollpos > 1) then -- up
    self._scrollpos = self._scrollpos - 1
  elseif (dir == 1 and self._scrollpos <= (#self._lines - h)) then -- down
    self._scrollpos = self._scrollpos + 1
  end
end

m.display = function(self, win)
  -- self:_buildUI(win)
  win.clear()
  local w, h = win.getSize()
  win.setCursorPos(1, 1)

  win.setTextColor(self._fcolor)
  win.setBackgroundColor(self._bcolor)

  local max = h + self._scrollpos - 1
  local lineIndex = 1
  for i = self._scrollpos, max do
    win.setCursorPos(1, lineIndex)
    win.write(self._lines[i])
    lineIndex = lineIndex + 1
  end
end

m.displayStart = nil

--## Constructor ##--

--Common
m.new = function(_, lines)
  local o = {}
  setmetatable(o, { __index = m })
  if (lines == nil) then
    lines = {}
  end
  o._lines = lines
  return o
end

return m