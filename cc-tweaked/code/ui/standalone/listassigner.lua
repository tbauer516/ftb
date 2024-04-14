local m = {}

m._lines = {}
m._options = {}
m._scrollpos = 1
m._selectedRow = 1
m._selectedCol = 1
m.type = "interact"
m.rows = {}

--## Private Functions

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

m._wrapOptions = function(self, val, min, max)
  if (val < min) then
    val = max
  elseif (val > max) then
    val = min
  end
  return val
end

--## Public Functions

--dir: -1 is up, 1 is down
m.scroll = function(self, win, dir)
  local w, h = win.getSize()
  if (h >= #self._lines) then
    return
  elseif (self._selectedRow < self._scrollpos) then -- up
    self._scrollpos = self._selectedRow
  elseif (self._selectedRow > self._scrollpos + h - 1 and self._scrollpos <= (#self._lines - h)) then -- down
    self._scrollpos = self._selectedRow - h + 1
  end
end

m.selectRow = function(self, dir)
  if (dir == -1 and self._selectedRow > 1) then -- up
    self._selectedRow = self._selectedRow - 1
  elseif (dir == 1 and self._selectedRow <= #self._lines) then -- down
    self._selectedRow = self._selectedRow + 1
  end
end

m.selectCol = function(self, dir)
  if (dir == -1 and self._selectedCol > 1) then -- up
    self._selectedCol = self._selectedCol - 1
  elseif (dir == 1 and self._selectedCol < 2) then -- down
    self._selectedCol = self._selectedCol + 1
  end
end

m.changeOption = function(self, dir)
  if (self._selectedCol == 1) then
    self.rows[self._selectedRow]["rank"] = self:_wrapOptions(self.rows[self._selectedRow]["rank"] + dir, 1, #self.chests - 1)
  elseif (self._selectedCol == 2) then
    self.rows[self._selectedRow]["type"] = self:_wrapOptions(self.rows[self._selectedRow]["type"] + dir, 1, #self._options)
  end
end

m.display = function(self, win)
  win.clear()
  local w, h = win.getSize()
  win.setCursorPos(1, 1)

  local max = math.min(h + self._scrollpos - 1, #self.rows)
  local lineIndex = 1
  for i = self._scrollpos, max do
    win.setCursorPos(1, lineIndex)
    local col1 = self.rows[i]["rank"]
    local col2 = self._options[self.rows[i]["type"]]
    if (self._selectedRow == i and self._selectedCol == 1) then
      col1 = "[" .. col1 .. "]"
    elseif (self._selectedRow == i and self._selectedCol == 2) then
      col2 = "[" .. col2 .. "]"
    end
    win.write(col1 .. " | " .. col2 .. " | " .. self.rows[i]["id"])
    lineIndex = lineIndex + 1
  end
end

m.run = function(self, win)
  self:display(win)
  while true do
    local event = {os.pullEvent()}
    if (event[1] == "key") then
      if (event[2] == keys.down) then
        self:changeOption(-1)
      elseif (event[2] == keys.up) then
        self:changeOption(1)
      elseif (event[2] == keys.w) then
        self:selectRow(-1)
      elseif (event[2] == keys.s) then
        self:selectRow(1)
      elseif (event[2] == keys.a) then
        self:selectCol(-1)
      elseif (event[2] == keys.d) then
        self:selectCol(1)
      elseif (event[2] == keys.enter) then

      end
    end
    self:display(win)
  end
end

--## Constructor ##--

--Common
m.new = function(_, lines, options)
  local o = {}
  setmetatable(o, { __index = m })
  if (lines == nil) then
    lines = {}
  end
  o._lines = lines
  o._options = options

  for k,v in ipairs(lines) do
    o.rows[k] = {}
    o.rows[k]["rank"] = 1
    o.rows[k]["type"] = 1
    o.rows[k]["id"] = v
  end

  return o
end

return m