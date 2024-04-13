local subordinateFuelAmount = 1
local safeMode = false

------------------------

local h = nil

term.clear()
term.setCursorPos(1,1)
term.write("Please put some coal in my inventory")

local run = true
for i = 1,16 do
  local detail = turtle.getItemDetail(i)
  if detail ~= nil then
    turtle.select(i)
    if turtle.refuel(1) then
      run = false
      break
    end
  end
end

while run and turtle.getFuelLevel() < 2 do
  local inventory = {}
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail ~= nil then
      inventory[i] = detail.name
    else
      inventory[i] = nil
    end
  end

  sleep(0.05)
  os.pullEvent("turtle_inventory")

  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail ~= nil and inventory[i] == nil then
      turtle.select(i)
      if turtle.refuel(1) then
        run = false
        break
      end
    end
  end
end

term.clear()
term.setCursorPos(1,1)
term.write("Please give me a")
term.setCursorPos(1,2)
term.write("chest, disk drive and floppy")

local drive = false
local chest = false
local floppy = false

local success, data = turtle.inspectUp()
if success and data.name:find("chest",0,true) then chest = true end

turtle.turnLeft()
success, data = turtle.inspect()
turtle.turnRight()
if success and data.name:find("computercraft:disk_drive",0,true) then drive = true end
if success and data.state.state == "full" then floppy = true end

while drive == false or chest == false or floppy == false do
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
      if detail ~= nil and detail.name:find("computercraft:disk_drive",0,true) then
        turtle.turnLeft()
        turtle.select(i)
        turtle.place()
        turtle.turnRight()
        drive = true
      elseif detail ~= nil and detail.name:find("chest",0,true) then
        turtle.select(i)
        turtle.placeUp()
        chest = true
      elseif drive == true and detail ~= nil and detail.name:find("computercraft:disk",0,true) then
        turtle.turnLeft()
        turtle.select(i)
        turtle.drop()
        turtle.turnRight()
        floppy = true
      end
  end

  local items = {}
  if not chest then items[#items + 1] = "chest" end
  if not drive then items[#items + 1] = "disk drive" end
  if not floppy then items[#items + 1] = "floppy" end
  local itemString = ""
  for i=#items,1,-1 do
    itemString = items[i] .. itemString
    if #items > 1 and i == #items then
      itemString = " and " .. itemString
    elseif i > 1 then
      itemString = ", " .. itemString
    end
  end
  term.clear()
  term.setCursorPos(1,1)
  term.write("Please give me a")
  term.setCursorPos(1,2)
  term.write(itemString)

  if drive and chest and floppy then break end
  sleep(0.05)
  os.pullEvent("turtle_inventory")

  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
      if detail ~= nil and detail.name:find("computercraft:disk_drive",0,true) then
        turtle.turnLeft()
        turtle.select(i)
        turtle.place()
        turtle.turnRight()
        drive = true
      elseif detail ~= nil and detail.name:find("chest",0,true) then
        turtle.select(i)
        turtle.placeUp()
        chest = true
      elseif drive == true and detail ~= nil and detail.name:find("computercraft:disk",0,true) then
        turtle.turnLeft()
        turtle.select(i)
        turtle.drop()
        turtle.turnRight()
        floppy = true
      end
  end
end

sleep(0.1)
local diskDrive = peripheral.find("drive")

if diskDrive then
  local mountPath = diskDrive.getMountPath()
  if fs.exists(mountPath .. "/records") then
    fs.delete(mountPath .. "/records")
  end

  h = io.open(mountPath .. "/fuel","w")
  h:write(textutils.serialize(subordinateFuelAmount))
  h:close()
end

term.clear()
term.setCursorPos(1,1)
term.write("Give me a bunch of fuel")
local fuelCount = 0
term.setCursorPos(1,2)
term.write("You have enough fuel for " .. math.floor(fuelCount / subordinateFuelAmount) .. " turtles")
term.setCursorPos(1,4)
term.write("Press SPACEBAR when done")

run = true
local inventory = {}
for i = 1,16 do
  local detail = turtle.getItemDetail(i)
  if detail ~= nil then
    turtle.select(i)
    if turtle.refuel(0) then
      fuelCount = fuelCount + turtle.getItemCount()
      turtle.dropUp()
      term.setCursorPos(1,2)
      term.write("You have enough fuel for " .. math.floor(fuelCount / subordinateFuelAmount) .. " turtles")
    else
      inventory[i] = false
    end
  end
end


while run do
  sleep(0.05)
  local event = {os.pullEvent()}
  if event[1] == "key" and event[2] == 32 then
    run = false
    break
  elseif event[1] == "turtle_inventory" or event[1] == "timer" then
    for i = 1,16 do
      local detail = turtle.getItemDetail(i)
      if detail ~= nil and inventory[i] == nil then
        turtle.select(i)
        if turtle.refuel(0) then
          fuelCount = fuelCount + turtle.getItemCount()
          turtle.dropUp()
          term.setCursorPos(1,2)
          term.write("You have enough fuel for " .. math.floor(fuelCount / subordinateFuelAmount) .. " turtles")
        end
      end
    end
    os.startTimer(1)
  end
end

term.clear()
term.setCursorPos(1,1)
term.write("Give me " .. math.floor(fuelCount / subordinateFuelAmount) .. " turtles")
term.setCursorPos(1,2)
term.write("Clear space for me to back up")

local turtles = math.floor(fuelCount / subordinateFuelAmount)
local turtleCount = 0
while turtleCount < turtles do
  sleep(0.05)
  turtleCount = 0
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail ~= nil and detail.name:find("computercraft:turtle",0,true) then
      turtleCount = turtleCount + detail.count
      if turtleCount >= turtles then
        break
      end
    end
  end
end

while not turtle.back() do
  sleep(0.5)
end

term.clear()
term.setCursorPos(1,1)
term.write("Deploying turtles")

local hasTurtle = true
while turtles > 0 and hasTurtle do
  hasTurtle = false
  for i = 1,16 do
    local detail = turtle.getItemDetail(i)
    if detail ~= nil and detail.name:find("computercraft:turtle",0,true) then
      hasTurtle = true
      turtle.select(i)
      while turtles > 0 and turtle.getItemCount() > 0 do
        if turtle.place() then
          turtles = turtles - 1
          sleep(0.1)
          peripheral.call("front","turnOn")
          if safeMode then
            sleep(1.5)
          else
            while turtle.detect() do
              sleep(0.05)
            end
          end
        end
      end
    end
  end
end

term.clear()
term.setCursorPos(1,1)
turtle.forward()

sleep(0.1)
diskDrive = peripheral.find("drive")

if diskDrive then
  local mountPath = diskDrive.getMountPath()
  if fs.exists(mountPath .. "/records") then
    fs.delete(mountPath .. "/records")
  end

  if fs.exists(mountPath .. "/fuel") then
    fs.delete(mountPath .. "/fuel")
  end
end