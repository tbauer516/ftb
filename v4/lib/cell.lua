local m = {}

m._cell = nil
m._max = nil
m._min = nil
m._cur = nil
m._threshHigh = nil
m._threshMed = nil
m._colorHigh = colors.green
m._colorMed = colors.orange
m._colorLow = colors.red
m._colorBG = colors.gray
m._colorLabelBG = colors.black
m._colorFG = colors.white
m._ui = nil
m._x = nil
m._y = nil
m._w = nil
m._h = nil
m._label = nil
m.type = "auto"

--## Private Functions

m._calcValues = function(self)
  self._max = self._cell.getEnergyCapacity()
  self._min = 0
  self._cur = 0
  self._threshHigh = self._max * 0.5
  self._threshMed = self._max * 0.25
  self._uiMax = self._w
  self._uiMin = 0
end

m._scale = function(self, val)
  local range1 = self._max - self._min
  local range2 = self._uiMax - self._uiMin
  local perc = val / range1
  local scaled = math.floor((range2 * perc) + 0.5)
  return scaled
end

--## Public Functions

m.display = function(self, mon)
  local oldFColor = mon.getTextColor()
  local oldBColor = mon.getBackgroundColor()
  local color = self._colorLow
  if (self._cur > self._threshHigh) then
    color = self._colorHigh
  elseif (self._cur > self._threshMed) then
    color = self._colorMed
  end
  
  local amountString = string.sub(self._cur .. " / " .. self._max, 1, self._w)
  local label = string.sub(self._label, 1, self._w)
  for i = 1, self._w - string.len(self._label) do
    label = label .. " "
  end

  mon.setCursorPos(self._x, self._y)
  mon.setBackgroundColor(self._colorLabelBG)
  mon.setTextColor(self._colorFG)
  mon.write(label)

  local barwidth = self:_scale(self._cur)
  for i = 1, self._h - 1 do
    mon.setCursorPos(self._x, self._y + i)
    mon.setBackgroundColor(color)
    if (i == math.ceil(self._h / 2)) then
      if (string.len(amountString) > barwidth) then -- split string
        local first = string.sub(amountString, 1, barwidth)
        mon.write(first)
        mon.setBackgroundColor(self._colorBG)
        local last = string.sub(amountString, string.len(first) + 1, string.len(amountString))
        for i = 1, self._w - string.len(amountString) do
          last = last .. " "
        end
        mon.write(last)
      else -- don't split string, split spaces
        mon.write(amountString)
        for i = 1, barwidth - string.len(amountString) do
          mon.write(" ")
        end
        mon.setBackgroundColor(self._colorBG)
        for i = 1, self._w - barwidth do
          mon.write(" ")
        end
      end
    else
      for i = 1, barwidth do
        mon.write(" ")
      end
      mon.setBackgroundColor(self._colorBG)
      for i = 1, self._w - barwidth do
        mon.write(" ")
      end
    end
  end

  mon.setTextColor(colors.white)
  mon.setBackgroundColor(colors.black)
end

m.update = function(self)
  self._cur = self._cell.getEnergyStored()
end

--## Constructor ##--

m.new = function(_, x, y, w, h, label, cell)
  local o = {}
  setmetatable(o, { __index = m })
  -- self.__index = m
  o._x = x
  o._y = y
  o._w = w
  o._h = h
  o._label = label
  o._cell = cell
  o:_calcValues()
  return o
end

return m