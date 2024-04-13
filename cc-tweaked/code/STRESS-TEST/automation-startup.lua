local maxDist = 30
local rowWidth = 9

----------------------------

local refuelAmount = 1
local h = nil

if fs.exists("/disk/fuel") then
  h = io.open("/disk/fuel","r")
  refuelAmount = textutils.unserialize(h:read())
  h:close()
end

rowWidth = rowWidth - ((rowWidth + 1) % 2)

turtle.select(1)
turtle.suckUp(refuelAmount)
turtle.refuel()

if turtle.getFuelLevel() <= 0 then
  error("Out of fuel")
end

local count = ""
h = io.open("/disk/records","r")
if h ~= nil then
  for line in h:lines() do
    count = count .. line
  end
  h:close()
end
count = textutils.unserialize(count) or -1
count = count + 1

local instructions = {}
instructions.dir = count % 4
instructions.h = math.floor(math.floor(count / 4) / rowWidth)
--              number of full rotations, divide by 2 to get 2 sets of 4
--                 add 4 to initial to ignore first 4 0's                  get odd/even rotation, map 0 <-> 1 to -1 <-> 1
instructions.x = (math.ceil(math.floor((count % (rowWidth * 4)) / 4) / 2)) * (((math.floor(count / 4) % 2) * 2) - 1)

h = io.open("/disk/records","w")
h:write(textutils.serialize(count))
h:close()


if instructions.dir == 0 then -- go straight
  if turtle.detect() then turtle.dig() end
  turtle.forward()
elseif instructions.dir == 1 then -- go right
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  turtle.turnRight()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
elseif instructions.dir == 2 then -- go back
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  turtle.turnRight()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  turtle.turnRight()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
else                              -- go left
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  turtle.turnLeft()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
  if turtle.detect() then turtle.dig() end
  turtle.forward()
end


if instructions.x < 0 then
  turtle.turnLeft()
elseif instructions.x > 0 then
  turtle.turnRight()
end
for i=1,math.abs(instructions.x) do
  turtle.forward()
end
if instructions.x < 0 then
  turtle.turnRight()
elseif instructions.x > 0 then
  turtle.turnLeft()
end

for i=1,instructions.h do
  turtle.up()
end

local actualDist = math.min(maxDist, math.floor(turtle.getFuelLevel() / 2))
for i=1,actualDist do
  while turtle.detect() do
    turtle.dig()
    sleep(0.1)
  end
  assert(turtle.forward())
end

turtle.turnRight()
turtle.turnRight()

for i=1,actualDist - 5 do
  while turtle.detect() do
    turtle.dig()
    sleep(0.1)
  end
  assert(turtle.forward())
end

for i=1,16 do
  if turtle.getItemCount(i) > 0 then
    turtle.select(i)
    turtle.drop()
  end
end