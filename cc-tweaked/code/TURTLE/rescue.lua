local t = require("lib/t"):new()
local quarry = require("lib/quarry")

sleep(60)

if (fs.exists(t.locFile)) then
  local handleT = fs.open(t.locFile, "r")
  local currLoc = textutils.unserialize(handleT.readAll())
  handleT.close()
  t:setLoc(currLoc)

  if (fs.exists(quarry.locFile)) then
    local handleQ = fs.open(quarry.locFile, "r")
    local targetLoc = textutils.unserialize(handleQ.readAll())
    handleQ.close()
    print("Performing rescue attempt...")
    print("From: " .. t:getLocString(t:getLoc()))
    print("To  : " .. t:getLocString(targetLoc))
    local finalY = targetLoc.y
    targetLoc.y = math.min(currLoc.y + quarry.bedrockDangerZone, finalY)
    t:moveTo(targetLoc)
    targetLoc.y = finalY
    t:moveTo(targetLoc)
    fs.delete("startup.lua")
    fs.delete(quarry.locFile)
    fs.delete(t.locFile)
  end
end