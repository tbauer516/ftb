local m = {}

m._fcolor = colors.white
m._bcolor = colors.lightGray
m._currentText = ""
m._textTrie = {}
m._x = nil
m._y = nil
m._w = nil
m._h = nil
m.type = {"keyboard"}

--## Private Functions

m._keyboard = function() error("need to 'setKeyboard' for the searchbar") end

--## Public Functions

m.setKeyboard = function(self, func)
  self._keyboard = func
end

m.keyboard = function(self, eventName, character, isHeld)
  if (eventName == "key") then
    if (character == nil) then
      -- do nothing
    elseif (character == keys.delete) then
      self._currentText = ""
    elseif (character == keys.backspace) then
      self._currentText = string.sub(self._currentText, 1, #self._currentText - 1)
    end
  elseif (eventName == "char") then
    self._currentText = self._currentText .. character
  end
  self._keyboard(self._currentText)
end

m.clear = function(self)
  self._currentText = ""
end

m.display = function(self, win)
  win.clear()
  local w, h = win.getSize()
  win.setCursorPos(1, 1)

  win.setTextColor(self._fcolor)
  win.setBackgroundColor(self._bcolor)

  local toDisplay = self._currentText
  for i = #self._currentText, w do
    toDisplay = toDisplay .. " "
  end

  win.write(toDisplay)
end

m.displayStart = nil

--## Constructor ##--

--Common
m.new = function(_)
  local o = {}
  setmetatable(o, { __index = m })
  return o
end

return m