local n = require("lib/networking"):new()

local dependencies = {
  "lib/",
  "tablet.lua",
}

--## Main Runtime ##--

os.setComputerLabel("Mining Tablet " .. os.computerID())

if (not pocket) then
  local diskPath = disk.getMountPath("bottom")
  local tabPath = disk.getMountPath("top")
  if (diskPath == nil or tabPath == nil) then
    error("Please put the tablet on top and the floppy on the bottom disk drive")
  end
  if (fs.exists(diskPath .. "/")) then
    for i,v in ipairs(dependencies) do
      if (fs.exists(tabPath .. "/" .. v)) then fs.delete(tabPath .. "/" .. v) end
      fs.copy(diskPath .. "/"..v, tabPath .. "/" .. v)
    end
  end
  fs.copy(tabPath .. "/tablet.lua", tabPath .. "/startup.lua")
end
if (not n:checkModem()) then
  error("Please run on a wireless pocket computer")
end

while true do
  term.clear()
  term.setCursorPos(1,1)
  term.write("Waiting for server request")
  n:waitToSendAvailability()
  n:sendCoords()
end