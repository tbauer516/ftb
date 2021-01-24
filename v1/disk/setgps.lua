local args = {...}

-- East Z+
-- South X+

if (#args ~= 3) then
  print("usage: setgps <turtle number in sequence> <x> <z>")
  error()
end

local num = tonumber(args[1])
local x = args[2]
local z = args[3]
local y = 256

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
  y = 254
end

while turtle.up() do end

if (num == 4) then
  turtle.down()
end

local h = fs.open("startup", "w")
h.writeLine("shell.run(\"gps\",\"host\",\"" .. x .. "\",\"" .. y .. "\",\"" .. z .. "\")")
h.close()

os.reboot()