local args = {...}

-- East Z+
-- South X+

local firstTime = true
local persistent = {}

if (fs.exists("disk/gpsdata.txt")) then
  local h = fs.open("disk/gpsdata.txt", "r")
  local fileData = h.readAll()
  h.close()
  firstTime = false
  persistent = textutils.unserialize(fileData)
end

if (firstTime and #args ~= 2) then
    print("usage: setgps <x> <z>")
    print("while facing north")
    error()
end

if (firstTime) then
  fs.copy("disk/setgps.lua", "disk/startup.lua")
end

os.setComputerLabel("GPS "..os.computerID())

while turtle.getFuelLevel() < 300 do
  term.clear()
  term.setCursorPos(1,1)
  print("Please add fuel. Fuel level: " .. turtle.getFuelLevel())
  for i=1,16 do
    if (turtle.getItemCount(i) > 0) then
      turtle.select(i)
      turtle.refuel()
    end
  end
  sleep(1)
end
term.clear()

local num = persistent.num or 0
num = num + 1
local x = persistent.x or tonumber(args[1])
local z = persistent.z or tonumber(args[2])
local y = 255

persistent.num = num
persistent.x = x
persistent.z = z

if (num == 4) then
  fs.delete("disk/gpsdata.txt")
  fs.delete("disk/startup.lua")
else
  local h = fs.open("disk/gpsdata.txt", "w")
  h.write(textutils.serialize(persistent))
  h.close()
end

if (num == 1) then
  turtle.forward()
  turtle.forward()
  turtle.turnLeft()
  turtle.forward()
  turtle.forward()
  turtle.turnRight()
  x = x - 2
  z = z - 2
elseif (num == 2) then
  turtle.forward()
  turtle.forward()
  z = z - 2
elseif (num == 4) then
  turtle.forward()
  turtle.forward()
  z = z - 2
  y = 253
end

while turtle.up() do end

if (num == 4) then
  turtle.down()
end

local h = fs.open("startup", "w")
h.writeLine("shell.run(\"gps\",\"host\",\"" .. x .. "\",\"" .. y .. "\",\"" .. z .. "\")")
h.close()

os.reboot()