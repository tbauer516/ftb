local args = {...}

-- East X+
-- South Z+

local firstTime = true
local persistent = {}

if (fs.exists("disk/gpsdata.txt")) then
  local h = fs.open("disk/gpsdata.txt", "r")
  local fileData = h.readAll()
  h.close()
  firstTime = false
  persistent = textutils.unserialize(fileData)
end

if (firstTime and #args ~= 3) then
    print("usage: setlowgps <x> <y> <z>")
    print("while facing north")
    error()
end

if (firstTime) then
  if (fs.exists("disk/startup.lua")) then
    fs.delete("disk/startup.lua")
  end
  fs.copy("disk/setlowgps.lua", "disk/startup.lua")
end

os.setComputerLabel("GPS "..os.computerID())

while turtle.getFuelLevel() < 5 do
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
local y = persistent.y or tonumber(args[2])
local z = persistent.z or tonumber(args[3])

persistent.num = num
persistent.x = x
persistent.y = y
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
  turtle.forward()
  z = z - 3
elseif (num == 2) then
  turtle.turnLeft()
  turtle.forward()
  turtle.forward()
  turtle.forward()
  x = x - 3
elseif (num == 3) then
  turtle.up()
  turtle.up()
  turtle.up()
  y = y + 3
end

local h = fs.open("startup.lua", "w")
h.writeLine("shell.run(\"gps\",\"host\",\"" .. x .. "\",\"" .. y .. "\",\"" .. z .. "\")")
h.close()

os.reboot()
