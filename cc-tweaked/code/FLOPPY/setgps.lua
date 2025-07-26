local args = { ... }

-- East X+
-- South Z+

local firstTime = true
local persistent = {} -- should be table
local worldHeight = 319

if fs.exists("disk/gpsdata.txt") then
	local h = fs.open("disk/gpsdata.txt", "r")
	local fileData = ""
	if h ~= nil then
		fileData = h.readAll() or ""
		h.close()
	end
	firstTime = false
	local fileDataUnserialized = textutils.unserialize(fileData)
	if type(fileDataUnserialized) == "table" then
		persistent = fileDataUnserialized
	end
end

if firstTime and (#args < 3 or #args > 4) then
	print("usage: setgps <x> <y> <z> [<height>]")
	print("face north. place turtle in NE corner.")
	print("turtles will go 6 left and 6 back.")
	error()
end

if firstTime then
	fs.copy("disk/setgps.lua", "disk/startup.lua")
end

os.setComputerLabel("GPS " .. os.computerID())

if type(persistent) ~= "table" then
	persistent = {}
end

local num = persistent.num or 0
num = num + 1
local x = persistent.x or tonumber(args[1])
local y = persistent.y or tonumber(args[2])
local initialY = y
local z = persistent.z or tonumber(args[3])
local heightCap = persistent.heightCap or tonumber(args[4]) or (worldHeight - y)

persistent.num = num
persistent.x = x
persistent.y = y
persistent.z = z
persistent.heightCap = heightCap

while turtle.getFuelLevel() < heightCap * 2 do
	term.clear()
	term.setCursorPos(1, 1)
	print("Please add fuel. Fuel level: " .. turtle.getFuelLevel())
	for i = 1, 16 do
		if turtle.getItemCount(i) > 0 then
			turtle.select(i)
			turtle.refuel()
		end
	end
	sleep(1)
end
term.clear()

if num == 4 then
	fs.delete("disk/gpsdata.txt")
	fs.delete("disk/startup.lua")
else
	local h = fs.open("disk/gpsdata.txt", "w")
	if h ~= nil then
		h.write(textutils.serialize(persistent))
		h.close()
	end
end

if num == 2 then
	turtle.turnLeft()
	for _ = 1, 6, 1 do
		turtle.forward()
	end
	turtle.turnRight()
	x = x - 6
elseif num == 3 then
	for _ = 1, 6, 1 do
		turtle.back()
	end
	z = z + 6
end

-- check until 1 below, then move up 1 to meet cap
while (y - initialY < heightCap) and turtle.up() do
	y = y + 1
end

if num == 4 then
	for _ = 1, 6, 1 do
		turtle.down()
	end
	y = y - 6
end

local h = fs.open("startup", "w")
if h ~= nil then
	h.writeLine('shell.run("gps","host","' .. x .. '","' .. y .. '","' .. z .. '")')
	h.close()
end

os.reboot()
