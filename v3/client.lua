-- package.loaded.networking = nil
-- package.loaded.t = nil
-- package.loaded.quarry = nil
local n = require("lib/networking"):new()
local t = require("lib/t"):new(n)
local quarry = require("lib/quarry")

local dependencies = {
  "blacklist/",
  "lib/",
  "client.lua",
}

--## Variables ## --

local args = { ... }

--## Translate Network Instructions ##--

local lookup = function(action, params)
  if (action == "MOVE") then
    t:setStatus("Cruising")
    t:cruiseTo(unpack(params))
  elseif (action == "MINE") then
    -- local oldLoc = t:getLoc()
    -- t:setLoc(t.homeLoc)
    -- t.homeLoc = t:getLoc()
    local quarryinstance = quarry:new(t, unpack(params))
    quarryinstance:start()
    -- t:setLoc(oldLoc)
  elseif (action == "CRUISE") then
    t:setCruise(t.homeLoc.y + 3 + unpack(params))
  elseif (action == "ABORT") then
    print("Abort received")
  elseif (action == "TIMEOUT") then
    print(unpack(params))
  elseif (action == "SETHOME") then
    print("Setting new home")
    t:setLocFromGPS()
  end
end

--## Main Runtime ##--

os.setComputerLabel("Miner " .. os.computerID())

if (not n:checkModem()) then
  error("Please run on a wireless mining turtle")
end

if (fs.exists("disk/")) then
  fs.delete("startup.lua")
  for i,v in ipairs(dependencies) do
    if (fs.exists(v)) then fs.delete(v) end
    fs.copy("disk/"..v, v)
  end
  fs.copy("client.lua", "startup.lua")
end

sleep(5)

t:setLocFromGPS()

while true do
  t:setStatus("Idle")
  t:sendLoc()
  print("Waiting for instructions")
  local instructions = n:waitForServerJob()
  print("Executing instructions")
  for i=1,#instructions do
    lookup(instructions[i][1], instructions[i][2])
  end
  t:setStatus("Complete")
  t:sendLoc()
  rednet.send(n.serverID, "", n.request.completed)
end


-- quarry = quarry:new(t, tonumber(args[1]), tonumber(args[2]), args[3])
-- quarry:start()