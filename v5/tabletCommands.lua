local n = require("lib/networking"):new()
local mineCalc = require("lib/minecalc"):new()
local ui = require("lib/ui"):new()
local button = require("lib/button")

local dependencies = {
  "lib/",
  "tabletSendMineLoc.lua",
  "tabletCommands.lua",
}

--## Graphics Functions ##--

local printTurtleSelect = function(clients, selected, printArgs)
  local offset = printArgs.offset
  local max = printArgs.max
  local scroll = -1 * printArgs.scrollY
  local termSize = printArgs.termSize

  term.clear()

  for i=1,#clients do
    local found = false
    for j=1,#selected do
      if (clients[i] == selected[j]) then
        found = true
        break
      end
    end
    term.setCursorPos(1, i + offset + scroll)
    term.clearLine()
    term.setCursorPos(2, i + offset + scroll)
    if (found) then
      term.blit(" ", "0", "d")
    else
      term.blit(" ", "0", "e")
    end
    term.write(" "..clients[i])
  end

  term.setCursorPos(1, 1)
  term.clearLine()
  term.blit("  Send  ", "00000000", "dddddddd")
  term.write(" Max of "..max.." allowed")

  term.setCursorPos(1, 2)
  term.clearLine()
  term.blit(" Cancel ", "00000000", "eeeeeeee")
  term.write(" Cancel the command")

  term.setCursorPos(1, 3)
  term.clearLine()
end

--## Command Functions ##--

local handleCommandMove = function(selected)
  term.clear()
  term.setCursorPos(1,1)
  print("Getting coords")
  local loc = {gps.locate()}
  loc[1] = math.floor(loc[1])
  loc[2] = math.floor(loc[2]) - 1
  loc[3] = math.floor(loc[3])
  local newLoc = {
    {x=loc[1]-1, y=loc[2], z=loc[3], d=0},
    {x=loc[1]+1, y=loc[2], z=loc[3], d=2},
    {x=loc[1], y=loc[2], z=loc[3]-1, d=1},
    {x=loc[1], y=loc[2], z=loc[3]+1, d=3},
  }
  print("Sending coords to turtles: {"..loc[1]..","..loc[2]..","..loc[3].."}")
  
  local available = n:getAvailable(5)
  local found = 0
  for i=1,#available do
    for j=1,#selected do
      if (available[i] == selected[j]) then
        found = found + 1
      end
    end
  end
  if (found < #selected) then
    print("List of selected turtles no longer available")
    print("Found: " .. found)
    print("Selected: ")
    print(textutils.serialize(selected))
    sleep(5)
  else
    n:sendInstructionsForMoveHome(selected, newLoc)
  end
end

local selectTurtles = function(clients, max)
  table.sort(clients)

  local selected = {}
  local scrollY = 0
  local offset = 3
  local termSize = {term.getSize()}
  local printArgs = {max = max, scrollY = scrollY, offset = offset, termSize = termSize}
  printTurtleSelect(clients, selected, printArgs)

  while true do
    local event = {os.pullEvent()}
    if (event[1] == "mouse_scroll") then
      if (#clients + offset > termSize[2] and scrollY + event[2] >= 0 and scrollY + event[2] <= #clients + offset - termSize[2]) then
        term.scroll(event[2])
        scrollY = scrollY + event[2]
        printArgs.scrollY = scrollY
        printTurtleSelect(clients, selected, printArgs)
      end
    elseif (event[1] == "mouse_click") then
      local action = "add"
      if (event[4] == 1) then
        break
      elseif (event[4] == 2) then
        return {}
      elseif (event[4] > offset and event[4] >= offset - scrollY and event[4] <= #clients + offset) then
        for i=1,#selected do
          if (selected[i] == clients[event[4] - offset + scrollY]) then
            table.remove(selected, i)
            action = "rem"
          end
        end
        if (#selected < 4 and action == "add") then
          selected[#selected + 1] = clients[event[4] - offset + scrollY]
        end
      end
      printTurtleSelect(clients, selected, printArgs)
    end
  end

  return selected
end

local getTurtlesForMove = function()
  term.clear()
  term.setCursorPos(1,1)
  print("Waiting for availability from turtles")

  local clients = n:getAvailable(0.5)
  if (#clients == 0) then
    print("No turtles available")
    sleep(3)
  end

  return clients
end

local handleCommandMine = function()
  local coords = n:getCoords()
  local loc1 = coords[1]
  local loc2 = coords[2]
  local dir = mineCalc:getDir(loc1, loc2)
  local clients = n:getAvailable()

  if (#clients > 0) then
    local coords = mineCalc:divideClients(loc1, loc2, dir, #clients)
    n:sendInstructionsForMine(clients, coords)
    term.clear()
  end
end

--## Main Runtime ##--

os.setComputerLabel("Mining Tablet " .. os.computerID())

if (not pocket) then
  local diskPath = disk.getMountPath("bottom")
  local tabPath = disk.getMountPath("top")
  if (diskPath == nil or tabPath == nil) then
    error("Please put the tablet on top and the floppy on the bottom disk drive")
  end
  if (fs.exists(diskPath .. "/")) then
    if (fs.exists(tabPath .. "/startup.lua")) then
      fs.delete(tabPath .. "/startup.lua")
    end
    for i,v in ipairs(dependencies) do
      if (fs.exists(tabPath .. "/" .. v)) then fs.delete(tabPath .. "/" .. v) end
      fs.copy(diskPath .. "/"..v, tabPath .. "/" .. v)
    end
  end
  fs.copy(tabPath .. "/tabletCommands.lua", tabPath .. "/startup.lua")
  error("Files copied to tablet. Please use that.")
end
if (not n:checkModem()) then
  error("Please run on a wireless pocket computer")
end

if (multishell) then
  monitorShellID = shell.openTab("tabletSendMineLoc.lua")
  multishell.setTitle(multishell.getCurrent(), "commands")
  multishell.setTitle(monitorShellID, "send loc")
end


term.clear()

local size = {term.getSize()}

local paddingH = 4
local buttonH1 = math.floor(size[2] / 2) - paddingH
local buttonH2 = math.ceil(size[2] / 2) - paddingH
local buttonW = math.floor(size[1] / 1) - 2

local butMove4 = button:newStatic((size[1] / 2) - (buttonW / 2) + 1, math.floor(size[2] / 4) - math.floor(buttonH1 / 2) + 1, buttonW, buttonH1, "Move 4 Turtles Here")
local butMine = button:newStatic((size[1] / 2) - (buttonW / 2) + 1, math.ceil(3 * (size[2] / 4)) - math.ceil(buttonH1 / 2), buttonW, buttonH1, "Send Turtles To Mine")

butMove4:setClick(function()
  local clients = getTurtlesForMove()
  if (#clients > 0) then
    local selected = selectTurtles(clients, 4)
    if (#selected > 0) then
      handleCommandMove(selected)
    end
  end
  term.clear()
  ui:displayAll()
end)

butMine:setClick(function()
  handleCommandMine()
  term.clear()
  ui:displayAll()
end)

ui:add(butMove4, term.current())
ui:add(butMine, term.current())
ui:run()