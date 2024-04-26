local t = require("lib/t"):new()
local quarry = require("lib/quarry")

--## Variables ## --

os.setComputerLabel("Miner " .. os.computerID())

local args = { ... }
if (#args < 2 or #args > 3) then
  print("Place turtle will move forward <length> and to the right <width> when running.")
  print("Place fuel in slot 16 (last) and material to fill holes in slot 15.")
  print("If no blacklist is chosen, then default.blist will be used if it is available.")
  print()
  print("usage: mine <length> <width> [<alternate blacklist name>]")
  error()
end

--## Main Runtime ##--

quarry = quarry:new(t, tonumber(args[1]), tonumber(args[2]), args[3])

if (fs.exists("startup.lua")) then
  fs.delete("startup.lua")
end
fs.copy("rescue.lua", "startup.lua")


t:saveLoc(quarry.initialLoc, quarry.locFile)
quarry:start()

fs.delete("startup.lua")
fs.delete(quarry.locFile)
fs.delete(t.locFile)