local m = {}

m._max = 15
m._min = 0
m._cur = 0
m._threshHigh = 0.5
m._threshMed = 0.25
m._uiMin = 0
m._uiMax = nil
m._colorHigh = colors.green
m._colorMed = colors.orange
m._colorLow = colors.red
m._colorBG = colors.gray
m._colorLabelBG = colors.black
m._colorFG = colors.white
m._label = nil
m.type = {"displayonly"}

--## Private Functions

m._scale = function(self, val)
  local range1 = self._max - self._min
  local range2 = self._uiMax - self._uiMin
  local perc = val / range1
  local scaled = math.floor((range2 * perc) + 0.5)
  return scaled
end

--## Public Functions

m.display = function(self, win)
  local w, h = win.getSize()
  self._uiMax = w

  local color = self._colorLow
  if (self._cur > self._max * self._threshHigh) then
    color = self._colorHigh
  elseif (self._cur > self._max * self._threshMed) then
    color = self._colorMed
  end
  
  local amountString = string.sub(self._cur .. " / " .. self._max, 1, w)
  local label = string.sub(self._label, 1, w)
  for i = 1, w - string.len(self._label) do
    label = label .. " "
  end

  win.setCursorPos(1, 1)
  win.setBackgroundColor(self._colorLabelBG)
  win.setTextColor(self._colorFG)
  win.write(label)

  local barwidth = self:_scale(self._cur)
  for i = 1, h - 1 do
    win.setCursorPos(1, 1 + i)
    win.setBackgroundColor(color)
    if (i == math.ceil(h / 2)) then
      if (string.len(amountString) > barwidth) then -- split string
        local first = string.sub(amountString, 1, barwidth)
        win.write(first)
        win.setBackgroundColor(self._colorBG)
        local last = string.sub(amountString, string.len(first) + 1, string.len(amountString))
        for i = 1, w - string.len(amountString) do
          last = last .. " "
        end
        win.write(last)
      else -- don't split string, split spaces
        win.write(amountString)
        for i = 1, barwidth - string.len(amountString) do
          win.write(" ")
        end
        win.setBackgroundColor(self._colorBG)
        for i = 1, w - barwidth do
          win.write(" ")
        end
      end
    else
      for i = 1, barwidth do
        win.write(" ")
      end
      win.setBackgroundColor(self._colorBG)
      for i = 1, w - barwidth do
        win.write(" ")
      end
    end
  end
end

m.setMinMax = function(self, min, max)
  self._min = min
  self._max = max
end

m.setVal = function(self, val)
  self._cur = val
end

m.setUpdate = function(self, func, ...)
  local args = {...}
  self.update = function(self)
    func(unpack(args))
  end
end

m.update = nil

--## Constructor ##--

m.new = function(_, label)
  local o = {}
  setmetatable(o, { __index = m })
  o._label = label
  return o
end

return m