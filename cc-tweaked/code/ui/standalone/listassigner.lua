local m = {}

m._lines = {}
m._options = {}
m._scrollpos = 1
m._selectedRow = 1
m._selectedCol = 1
m.type = "interact"
m.rows = {}

--## Private Functions

m._wrapOptions = function(self, val, min, max)
  if (min <= max and val < min) then
    val = max
  elseif (min <= max and val > max) then
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
    self.rows[self._selectedRow]["rank"] = self:_wrapOptions(self.rows[self._selectedRow]["rank"] + dir, 1, #self.rows - 1)
  elseif (self._selectedCol == 2) then
    self.rows[self._selectedRow]["type"] = self:_wrapOptions(self.rows[self._selectedRow]["type"] + dir, 1, #self._options)
  end
end

m.validate = function(self, results)
  if (#self._lines == 1) then return true end
  local total = 0
  for i, option in ipairs(self._options) do
    local optionTotal = 0
    for j = 1, #results[option] do
      if (results[option][j] == nil) then return false end
      total = total + 1
      optionTotal = optionTotal + 1
    end
    if (optionTotal == 0) then return false end
  end
  if (total ~= #self._lines) then return false end
  return true
end

m.submit = function(self)
  local results = {}
  for k,v in ipairs(self._options) do
    results[v] = {}
  end
  for k,v in ipairs(self.rows) do
    local subTable = self._options[v.type]
    results[subTable][v.rank] = v.id
  end
  return results
end

m.display = function(self, win)
  win.clear()
  local w, h = win.getSize()
  win.setCursorPos(1, 1)

  local max = math.min(h + self._scrollpos - 1, #self.rows)
  local lineIndex = 1
  local col1W = 1
  local col2W = 1
  for i = self._scrollpos, max do
    col1W = math.max(col1W, #tostring(self.rows[i]["rank"]))
    col2W = math.max(col2W, #self._options[self.rows[i]["type"]])
  end
  for i = self._scrollpos, max do
    win.setCursorPos(1, lineIndex)
    local col1 = tostring(self.rows[i]["rank"])
    for i = 1,col1W - #col1 do
      col1 = " " .. col1
    end
    local col2 = self._options[self.rows[i]["type"]]
    for i = 1, math.floor((col2W - #col2) / 2) do
      col2 = " " .. col2
    end
    for i = 1, col2W - #col2 do
      col2 = col2 .. " "
    end

    if (self._selectedRow == i and self._selectedCol == 1) then
      col1 = "[" .. col1 .. "]"
      col2 = " " .. col2 .. " "
    elseif (self._selectedRow == i and self._selectedCol == 2) then
      col1 = " " .. col1 .. " "
      col2 = "[" .. col2 .. "]"
    else
      col1 = " " .. col1 .. " "
      col2 = " " .. col2 .. " "
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
        local results = self:submit()
        if (self:validate(results)) then
          return results
        else
          term.clear()
          term.setCursorPos(1,1)
          print("Did not pass validation")
          sleep(2)
        end
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