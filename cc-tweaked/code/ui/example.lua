local ui = require("ui/uimanager"):new()
local button = require("ui/button")
local hbar = require("ui/hbar")


term.clear()

local wireMon = peripheral.wrap("monitor_0")
wireMon.setTextScale(0.5)
local mon = peripheral.wrap("right")
mon.setTextScale(0.5)

local button1 = button:newToggle("123456789123456789")
local button2 = button:newStatic("123456789123456789123456789")
local hbar1 = hbar:new("redstone test")

button1:setClick(function()
  rs.setOutput("top", button1:getState())
end)

button2:setClick(function()
  rs.setOutput("top", not rs.getOutput("top"))
  sleep(.3)
  rs.setOutput("top", not rs.getOutput("top"))
  sleep(.3)
  rs.setOutput("top", not rs.getOutput("top"))
  sleep(.3)
  rs.setOutput("top", not rs.getOutput("top"))
end)

hbar1:setMinMax(0, 100)

hbar1:setUpdate(function()
  local input = rs.getAnalogInput("back")
  hbar1:setVal(math.floor(input * 100/15))
end)

ui:add(button1, 2, 2, 10, 9)
ui:add(button1, 1, 1, wireMon.getSize(), 12, "monitor_0")

ui:add(button2, 13, 2, 10, 9)
ui:add(button2, 1, 13, wireMon.getSize(), 12, "monitor_0")

ui:add(hbar1, 2, 12, term.getSize() - 2, 7)
ui:add(hbar1, 1, 1, mon.getSize(), select(2, mon.getSize()), "right")

ui:run()
