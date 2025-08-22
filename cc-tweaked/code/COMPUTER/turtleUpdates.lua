local n = require("lib/networking"):new()

--## Variables ##--

local maxID = 2
local maxX = 1
local maxY = 1
local maxZ = 1
local color1 = colors.gray
local color2 = colors.lightGray
local display = nil

local clients = {}

term.setPaletteColor(colors.lightGray, 0x737373)

--## Presentation Helpers ##--

local leftPad = function(str, maxLength)
	local paddedStr = tostring(str)
	for i = 1, maxLength - #tostring(str) do
		paddedStr = " " .. paddedStr
	end
	return paddedStr
end

local rightPad = function(str, maxLength)
	local paddedStr = tostring(str)
	for i = 1, maxLength - #tostring(str) do
		paddedStr = paddedStr .. " "
	end
	return paddedStr
end

local centerPad = function(str, maxLength)
	local paddedStr = tostring(str)
	local half = math.floor((maxLength - #tostring(str)) / 2)
	for i = 1, half do
		paddedStr = " " .. paddedStr .. " "
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

local _displayColor = function(client, loc, index)
	updateMaxWidths(client, loc.x, loc.y, loc.z)
	term.setCursorPos(1, 1)
	term.clearLine()
	term.setBackgroundColor(color1)
	term.write(" " .. centerPad("ID", maxID))
	term.setBackgroundColor(color2)
	term.write(" " .. centerPad("X", maxX))
	term.setBackgroundColor(color1)
	term.write(" " .. centerPad("Y", maxY))
	term.setBackgroundColor(color2)
	term.write(" " .. centerPad("Z", maxZ))
	term.setBackgroundColor(color1)
	term.write(" D")
	term.setBackgroundColor(color2)
	term.write(" S")

	term.setCursorPos(1, 2)
	term.setBackgroundColor(color1)
	term.clearLine()

	term.setCursorPos(1, index + 2)
	term.clearLine()
	term.setBackgroundColor(color1)
	term.write(" " .. centerPad(client, maxID))
	term.setBackgroundColor(color2)
	term.write(" " .. centerPad(loc.x, maxX))
	term.setBackgroundColor(color1)
	term.write(" " .. centerPad(loc.y, maxY))
	term.setBackgroundColor(color2)
	term.write(" " .. centerPad(loc.z, maxZ))
	term.setBackgroundColor(color1)
	term.write(" " .. loc.d)
	term.setBackgroundColor(color2)
	term.write(" " .. loc.s)
end

local _displayNotColor = function(client, loc, index)
	updateMaxWidths(client, loc.x, loc.y, loc.z)
	local seperator = " |"
	term.setCursorPos(1, 1)
	term.clearLine()
	term.write(" " .. centerPad("ID", maxID) .. seperator)
	term.write(" " .. centerPad("X", maxX) .. seperator)
	term.write(" " .. centerPad("Y", maxY) .. seperator)
	term.write(" " .. centerPad("Z", maxZ) .. seperator)
	term.write(" D " .. seperator)
	term.write(" S")

	term.setCursorPos(1, index + 2)
	term.clearLine()
	term.write(" " .. centerPad(client, maxID) .. seperator)
	term.write(" " .. centerPad(loc.x, maxX) .. seperator)
	term.write(" " .. centerPad(loc.y, maxY) .. seperator)
	term.write(" " .. centerPad(loc.z, maxZ) .. seperator)
	term.write(" " .. loc.d .. seperator)
	term.write(" " .. loc.s)
end

local getIndex = function(client)
	for i, v in ipairs(clients) do
		if v.client == client then
			return i
		end
	end
	return nil
end

local updateLocations = function(client, loc)
	local found = false
	for i, v in ipairs(clients) do
		if v.client == client then
			found = true
			v.loc = loc
		end
	end
	if not found and display ~= nil then
		clients[#clients + 1] = { client = client, loc = loc }
		table.sort(clients, function(a, b)
			return a.client < b.client
		end)
		for i, v in ipairs(clients) do
			display(v.client, v.loc, i)
		end
	end
	local index = getIndex(client)

	if display ~= nil then
		display(client, loc, index)
	end
end

--## Main Runtime ##--

display = _displayNotColor
if term.isColor() then
	display = _displayColor
end

n:listenForUpdatesStandalone(updateLocations)

