local t = require("lib/t"):new()
local quarry = require("lib/quarry")

sleep(60)

local currLoc = nil
if fs.exists(t.locFile) then
	local handleT = fs.open(t.locFile, "r")
	if handleT ~= nil then
		local handleTString = handleT.readAll()
		if type(handleTString) == "string" then
			local currLocTemp = textutils.unserialize(handleTString)
			currLoc = currLocTemp
		end
		handleT.close()
	end
	t:setLoc(currLoc)

	local targetLoc = nil
	if fs.exists(quarry.locFile) then
		local handleQ = fs.open(quarry.locFile, "r")
		if handleQ ~= nil then
			local targetLocString = handleQ.readAll()
			if type(targetLocString) == "string" then
				targetLoc = textutils.unserialize(targetLocString)
			end
			handleQ.close()
		end

		print("Performing rescue attempt...")
		print("From: " .. t:getLocString(t:getLoc()))
		print("To  : " .. t:getLocString(targetLoc))

		if targetLoc ~= nil and currLoc ~= nil then
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
end

