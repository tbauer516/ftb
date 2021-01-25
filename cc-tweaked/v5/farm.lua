local t = require("lib/t"):new()
local farm = require("lib/farm")

--## Variables ## --

local args = { ... }
if (#args < 1 or #args > 1) then
  print("Plant a farm in a 9x9 square with whatever plant you desire.")
  print("Place turtle facing the farm 2 blocks from the edge facing the center.")
  print("Place deposit chest to the right and fuel chest below the turtle. Killswitch to the left.")
  print()
  print("usage: farm run")
  error()
end

--## Main Runtime ##--

os.setComputerLabel("Farm " .. os.computerID())

if (args[1] == "run") then
  farm = farm:new(t)
  farm:run()
else
  print("valid arguments: run, build")
  error()
end