local t = require("lib/t"):new()
local farm = require("lib/birchfarm")

--## Variables ## --

local args = { ... }
if (#args < 1 or #args > 1) then
  print("Turtle will build from back left corner of chunk (meaning, it will move forward and to the right when building).")
  print("During 'run', place > 1 birch log in slot 16. During 'build' additionally place deposit chest in slot 1, sapling chest in slot 2.")
  print("You will have to place a row of water source block on the right and left side from back to front.")
  print()
  print("usage: treefarm <run or build>")
  error()
end

--## Main Runtime ##--

os.setComputerLabel("Tree Farm " .. os.computerID())

if (args[1] == "run") then
  farm = farm:new(t)
  farm:run()
elseif (args[1] == "build") then -- takes 10 min and 400 fuel
  local starttime = os.clock()
  
  farm = farm:new(t)
  t:initFuel(400)
  local fuelLevel = turtle.getFuelLevel()
  farm:build()

  local endtime = os.clock()
  local mins = math.floor((endtime - starttime) / 60)
  local seconds = math.floor((endtime - starttime) % 60)
  local runtime = mins .. "m " .. seconds .. "s"
  
  print()
  print("Fuel Used: "..(fuelLevel - turtle.getFuelLevel()))
  print("Runtime: " .. runtime)
else
    print("valid arguments: run, build")
    error()
end