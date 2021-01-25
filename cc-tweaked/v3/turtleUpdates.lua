local n = require("lib/networking"):new()

--## Variables ##--

local maxID = 2
local maxX = 1
local maxY = 1
local maxZ = 1

local clients = {}

--## Presentation Helpers ##--

local leftPad = function(str, maxLength)
  local paddedStr = tostring(str)
  for i=1,maxLength - #tostring(str) do
    paddedStr = " " .. paddedStr
  end
  return paddedStr
end

local rightPad = function(str, maxLength)
  local paddedStr = tostring(str)
  for i=1,maxLength - #tostring(str) do
    paddedStr = paddedStr .. " "
  end
  return paddedStr
end

local centerPad = function(str, maxLength)
  local paddedStr = tostring(str)
  local half = math.floor(maxLength - #tostring(str)) / 2
  for i=1,half do
    paddedStr = " " .. paddedStr .. " "
  end
  if (#tostring(str) % 2 == 1) then
    paddedStr = " " .. paddedStr
  end
  return paddedStr
end

local resetMaxWidths = function()
  maxID = 2
  maxX = 1
  maxY = 1
  maxZ = 1
end

local updateMaxWidths = function(id, x, y, z)
  maxID = math.max(maxID, #tostring(id))
  maxX = math.max(maxX, #tostring(x))
  maxY = math.max(maxY, #tostring(y))
  maxZ = math.max(maxZ, #tostring(z))
end

local display = function(client, loc, index)
  updateMaxWidths(client, loc.x, loc.y, loc.z)
  term.setCursorPos(1,1)
  term.clearLine()
  term.write(
    " "
    ..centerPad("ID", maxID).." | "
    ..centerPad("X", maxX).." | "
    ..centerPad("Y", maxY).." | "
    ..centerPad("Z", maxZ).." | "
    .."D | S"
  )
  term.setCursorPos(1, index + 2)
  term.clearLine()
  term.write(
    " "
    ..rightPad(client, maxID).." | "
    ..leftPad(loc.x, maxX).." | "
    ..leftPad(loc.y, maxY).." | "
    ..leftPad(loc.z, maxZ).." | "
    ..loc.d.." | "
    ..loc.s
  )
end

local getIndex = function(client)
  for i,v in ipairs(clients) do
    if (v.client == client) then
      return i
    end
  end
  return nil
end

local updateLocations = function(client, loc)
  local found = false
  for i,v in ipairs(clients) do
    if (v.client == client) then
      found = true
      v.loc = loc
    end
  end
  if (not found) then
    clients[#clients + 1] = {client = client, loc = loc}
    table.sort(clients, function(a, b) return a.client < b.client end)
    for i,v in ipairs(clients) do
      display(v.client, v.loc, i)
    end
  end
  local index = getIndex(client)

  display(client, loc, index)
end

--## Main Runtime ##--

n:listenForUpdatesStandalone(updateLocations)