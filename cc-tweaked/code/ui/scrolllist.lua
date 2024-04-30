local m = {}

m._fcolor = colors.white
m._bcolor = colors.black
m._lines = {} -- array with each element having { display = "", value = ""}
m._rawLines = {} -- display is display only, value is what is returned when clicked
m._scrollpos = 1
m._x = nil
m._y = nil
m._w = nil
m._h = nil
m.type = {"scroll","click"}

--## Private Functions

m._click = function() error("need to 'setClick' for the scrolllist") end

--## Public Functions

m.setLines = function(self, newLines)
  self._rawLines = newLines
  self._lines = newLines
  self._scrollpos = 1
end

m.filterLines = function(self, filterString)
  self._lines = {}
  for i = 1, #self._rawLines do
    local line = self._rawLines[i]
    if (string.find(line.value, filterString, 1, true)) then
      table.insert(self._lines, line)
    end
  end
  self._scrollpos = 1
end

m.setClick = function(self, func)
  self._click = func
end

-- determines item clicked, pass it to downstream
-- in main file, pass first variable with thing clicked and access in _click(arg1)
m.click = function(self, win, x, y)
  local w, h = win.getSize()
  local winX, winY = win.getPosition()
  self._click(self._lines[self._scrollpos + y - winY].value)
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

  local max = math.min(h + self._scrollpos - 1, #self._lines)
  local lineIndex = 1
  for i = self._scrollpos, max do
    win.setCursorPos(1, lineIndex)
    win.write(self._lines[i].display)
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
  o._rawLines = lines
  o._lines = lines
  return o
end

return m