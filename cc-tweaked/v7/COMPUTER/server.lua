local n = require("lib/networking"):new()
local t = require("lib/t"):new(n)
local mineCalc = require("lib/minecalc"):new()
local ui = require("ui/uimanager"):new()
local button = require("ui/button")

local dependencies = {
  "ui/",
  "lib/",
  "server.lua",
  "turtleUpdates.lua",
}

--## Variables ##--

local monitorShellID = nil

--## Helper Functions ##--



--## Onclick Functions ##--

local handleTurtleComms = function(loc1, loc2)
  local dir = mineCalc:getDir(loc1, loc2)
  local clients = n:getAvailable()

  if (#clients > 0) then
    local coords = mineCalc:divideClients(loc1, loc2, dir, #clients)
    n:sendInstructionsForMine(clients, coords)
    shell.switchTab(monitorShellID)
    term.clear()
  end
end

local manualEntry = function()
  term.clear()
  term.setCursorPos(1,1)
  term.write("Enter 2 coordinates at opposite corners:")
  term.setCursorPos(1,2)
  local loc1 = io.read()
  loc1 = textutils.unserialize("{" .. loc1 .. "}")
  term.setCursorPos(1,3)
  local loc2 = io.read()
  loc2 = textutils.unserialize("{" .. loc2 .. "}")

  handleTurtleComms(loc1, loc2)

  term.clear()
end

local tabletEntry = function()
  term.clear()
  term.setCursorPos(1,1)
  print("Waiting for availability from tablet")

  local tabletID = n:getAvailableTablet()
  if (tabletID == nil) then return end
  print("Waiting for coords from tablet")
  local coordsFromTablet = n:listenForCoordinates(tabletID)

  if (#coordsFromTablet > 0) then
    local loc1 = coordsFromTablet[1]
    local loc2 = coordsFromTablet[2]
    
    handleTurtleComms(loc1, loc2)
  end
  term.clear()
end


--## Main Loop ##--

os.setComputerLabel("Server " .. os.computerID())

if (not term.isColor()) then
  error("Please run this on an advanced computer")
end
if (not n:checkModem()) then
  error("Please add a wireless modem")
end

if (fs.exists("disk/")) then
  fs.delete("startup.lua")
  for i,v in ipairs(dependencies) do
    if (fs.exists(v)) then fs.delete(v) end
    fs.copy("disk/"..v, v)
  end
  fs.copy("server.lua", "startup.lua")
end

monitorShellID = shell.openTab("turtleUpdates.lua")
multishell.setTitle(multishell.getCurrent(), "ctrl")
multishell.setTitle(monitorShellID, "status")

term.clear()

local size = {term.getSize()}

local paddingW = 4
local buttonW1 = math.floor(size[1] / 2) - paddingW
local buttonW2 = math.ceil(size[1] / 2) - paddingW
local buttonH = math.floor(size[2] / 2) - 0

local butManual = button:newStatic("Manual Entry")
local butTablet = button:newStatic("Tablet Entry")

butManual:setClick(function()
  manualEntry()
  term.clear()
  ui:displayAll()
end)

butTablet:setClick(function()
  tabletEntry()
  term.clear()
  ui:displayAll()
end)

ui:add(butManual, math.floor(size[1] / 4) - math.floor(buttonW1 / 2) + 1, (size[2] / 2) - (buttonH / 2) + 1, buttonW1, buttonH)
ui:add(butTablet, math.ceil(3 * (size[1] / 4)) - math.ceil(buttonW2 / 2), (size[2] / 2) - (buttonH / 2) + 1, buttonW2, buttonH)
ui:run()