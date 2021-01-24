local n = require("lib/networking"):new()
local t = require("lib/t"):new(n)
local ui = require("lib/ui"):new()
local button = require("lib/button")
local cell = require("lib/cell")

local dependencies = {
  "lib/",
  "server.lua",
  "turtleUpdates.lua",
}

--## Variables ##--

local monitorShellID = nil

--## Helper Functions ##--

local getDir = function(p1, p2)
  local p02 = {p2[1] + -1 * p1[1], p2[2], p2[3] + -1 * p1[3]}

  if (p02[1] > 0 and p02[3] >= 0) then
    return 0
  elseif (p02[1] >= 0 and p02[3] < 0) then
    return 3
  elseif (p02[1] <= 0 and p02[3] > 0) then
    return 1
  elseif (p02[1] < 0 and p02[3] <= 0) then
    return 2
  else -- covers the 1x1 scenario
    return 0
  end
end

local divideClients = function(p1, p2, dir, numClients)
  local wDir = nil
  local l = nil
  local w = nil
  if (dir == 0) then
    wDir = 1
    l = "x"
    w = "z"
  elseif (dir == 1) then
    wDir = -1
    l = "z"
    w = "x"
  elseif (dir == 2) then
    wDir = -1
    l = "x"
    w = "z"
  elseif (dir == 3) then
    wDir = 1
    l = "z"
    w = "x"
  end
  
  local diffs = {x = math.abs(p2[1] - p1[1]) + 1, z = math.abs(p2[3] - p1[3]) + 1}

  local offset = math.floor(diffs[w] / numClients)
  local extra = diffs[w] % numClients

  if (offset < 1) then -- we have more clients than 1xn rows
    offset = 1
    extra = 0
    numClients = diffs[w]
  end

  local coords = {}
  local lastW = 0
  for i=1,numClients do
    local coord = {x = p1[1], y = p1[2], z = p1[3], d = dir}
    
    local additional = lastW + offset
    if (extra > 0) then
      additional = additional + 1
      extra = extra - 1
    end
    coord.w = additional - lastW
    coord.l = diffs[l]
    coord[w] = coord[w] + (wDir * lastW)
    lastW = additional
    
    coords[#coords + 1] = coord
  end

  return coords
end

--## Onclick Functions ##--

local handleTurtleComms = function(loc1, loc2)
  local dir = getDir(loc1, loc2)
  local clients = n:getAvailable()

  if (#clients > 0) then
    local coords = divideClients(loc1, loc2, dir, #clients)
    n:sendInstructionsForJob(clients, coords)
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

local butManual = button:newStatic(math.floor(size[1] / 4) - math.floor(buttonW1 / 2) + 1, (size[2] / 2) - (buttonH / 2) + 1, buttonW1, buttonH, "Manual Entry")
local butTablet = button:newStatic(math.ceil(3 * (size[1] / 4)) - math.ceil(buttonW2 / 2), (size[2] / 2) - (buttonH / 2) + 1, buttonW2, buttonH, "Tablet Entry")

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

ui:add(butManual, term.current())
ui:add(butTablet, term.current())
ui:run()