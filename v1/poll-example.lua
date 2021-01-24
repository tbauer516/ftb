term.clear()

local mon =  peripheral.wrap("monitor_0")
mon.setTextScale(0.5) -- 36, 24

local cell = peripheral.wrap("thermalexpansion:storage_cell_0")
local cell2 = peripheral.wrap("thermalexpansion:storage_cell_1")

local ui = require("lib/ui"):new()
local buttonFactory = require("lib/button")
local cellchartFactory = require("lib/cell")
local buttonToggle = buttonFactory:newToggle(1,3,10,3,"Count!")
local buttonStatic = buttonFactory:newStatic(1,7,10,3,"Count!")
local cellchart = cellchartFactory:new(1, 11, 17, 6, "Storage Cell 0", cell)
local cellchart2 = cellchartFactory:new(19, 11, 17, 6, "Storage Cell 1", cell2)

ui:add(buttonToggle, mon)
ui:add(buttonStatic, mon)
ui:add(cellchart, mon)
ui:add(cellchart2, mon)

local count = 0
local count2 = 0

local counter = function()
  mon.setCursorPos(1,1)
  mon.write(count)
  count = count + 1
end

local counter2 = function()
  mon.setCursorPos(6,1)
  mon.write(count2)
  count2 = count2 + 1
end

buttonToggle:setClick(counter)
buttonStatic:setClick(counter2)

counter()
counter2()

ui:run()