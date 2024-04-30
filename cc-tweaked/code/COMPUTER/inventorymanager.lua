local ui = require("ui/uimanager"):new()
local hbar = require("ui/hbar")
local button = require("ui/button")
local searchbar = require("ui/searchbar")
local scrolllist = require("ui/scrolllist")
local listassigner = require("ui/listassigner")

local args = { ... }
if (#args < 1) then -- or #args > 1) then
  print("Computer will manage an interface chest and any number of storage chests.")
  print("First run or the removal of the .clist file will put the program into assignment mode.")
  print("You will have to assign a chest as the interface, and the rest as storage.")
  print()
  print("usage: inventory-manager <run>")
  error()
end

--## Program Globals ##--

local inventoryManager = nil -- placeholder for instance

--## Module ##--

local m = {}

--## Variables to track state ##--

m.storageArray = {}
m.inventory = {} -- table were item.name is key, and value is array of tables {slot, chest, count}
m.interface = nil

m.interfaceFile = "interface.clist"

--## Helper functions ##--

m.getPeripherals = function(self)
  for i, name in ipairs(peripheral.getNames()) do
    if (name ~= "bottom" and name ~= "top" and name ~= "left" and name ~= "right" and name ~= "front" and name ~= "back") then
      for j, pType in ipairs({peripheral.getType(name)}) do
        if (pType == "inventory") then
          table.insert(self.storageArray, peripheral.wrap(name))
          break
        end
      end
    end
  end
  table.sort(self.storageArray, function(a, b)
    return peripheral.getName(a) < peripheral.getName(b)
  end)
end

m.hasChestsAssigned = function(self) -- wraps the peripherals
  if (fs.exists(self.interfaceFile)) then
    local handle = fs.open(self.interfaceFile, "r")
    local interfaceText = handle.readAll()
    self.interface = peripheral.wrap(interfaceText)
    handle.close()
  else
    return false
  end

  for i, chest in ipairs(self.storageArray) do
    if (peripheral.getName(self.interface) == peripheral.getName(chest)) then
      table.remove(self.storageArray, i)
      break
    end
  end

  return true
end

m.assignChests = function(self)
  local listOfNames = {}
  for i, chest in ipairs(self.storageArray) do
    table.insert(listOfNames, peripheral.getName(chest))
  end

  local assigner = listassigner:new(listOfNames, {"Storage", "Interface"})
  local assignments = assigner:run(term.native())
  for assignment, chests in pairs(assignments) do
    if (assignment == "Interface") then
      self.interface = peripheral.wrap(chests[1])
      break
    end
  end
  for i, chest in ipairs(self.storageArray) do
    if (peripheral.getName(self.interface) == peripheral.getName(chest)) then
      table.remove(self.storageArray, i)
      break
    end
  end

  local handle = fs.open(self.interfaceFile, "w")
  handle.write(peripheral.getName(self.interface))
  handle.close()
end

m.getInventoryList = function(self)
  local tempList = {}
  for name, spotArray in pairs(self.inventory) do
    local count = 0
    for i, location in ipairs(spotArray) do
      count = count + location.count
    end
    if (count > 999) then
      count = "999"
    else
      count = tostring(count)
      for i = #count, 2 do
        count = " " .. count
      end
    end
    local displayName = string.gsub(name, "(.*:)", "")
    table.insert(tempList, {display = count .. " | " .. displayName, value = name, sortName = displayName})
  end
  table.sort(tempList, function(a, b)
    return a.sortName < b.sortName
  end)
  return tempList
end

m.mapInventory = function(self)
  local items = {}
  for chesti, chest in ipairs(self.storageArray) do
    for slot, data in pairs(chest.list()) do
      local item = {slot = slot, chest = chest, count = data.count}
      if (items[data.name] == nil) then items[data.name] = {} end
      table.insert(items[data.name], item)
    end
  end
  for name, itemList in pairs(items) do
    table.sort(itemList, function(a, b)
      return a.count > b.count
    end)
  end
  self.inventory = items
  return items
end

m._getFreeSlot = function(self)
  local emptyIndex = nil
  local emptySlotChest = nil
  for i = #self.storageArray, 1, -1 do
    local chest = self.storageArray[i]
    for j = chest.size(), 1, -1 do
      local slot = j
      if (chest.list()[slot] == nil) then
        return {chest = chest, slot = slot}
      end
    end
  end
  return nil
end

m.consolidateInventory = function(self)
  local inventoryList = self:getInventoryList()
  table.sort(inventoryList, function(a, b)
    return a.value < b.value
  end)

  local chestI = 1
  local nextSortedIndex = 1

  for j = 1, #inventoryList do
    local itemName = inventoryList[j].value
    for k = 1, #self.inventory[itemName] do
      local itemToSort = self.inventory[itemName][k]

      local itemInTheWay = self.storageArray[chestI].getItemDetail(nextSortedIndex)

      if (itemInTheWay ~= nil and (self.storageArray[chestI] ~= itemToSort.chest or itemToSort.slot ~= nextSortedIndex)) then
        local empty = self:_getFreeSlot()
        if (empty == nil) then return end -- no empty slot
        for l = 1, #self.inventory[itemInTheWay.name] do
          if (self.inventory[itemInTheWay.name][l].chest == self.storageArray[chestI] and self.inventory[itemInTheWay.name][l].slot == nextSortedIndex) then
            self.inventory[itemInTheWay.name][l].chest = empty.chest
            self.inventory[itemInTheWay.name][l].slot = empty.slot
            break
          end
        end
        self.storageArray[chestI].pushItems(peripheral.getName(empty.chest), nextSortedIndex, itemInTheWay.count, empty.slot)
      end

      if (self.storageArray[chestI] ~= itemToSort.chest or itemToSort.slot ~= nextSortedIndex) then
        local transferred = self.storageArray[chestI].pullItems(peripheral.getName(itemToSort.chest), itemToSort.slot)
      end
      if (self.storageArray[chestI].getItemDetail(nextSortedIndex) ~= nil) then
        nextSortedIndex = nextSortedIndex + 1
      end
      if (nextSortedIndex > self.storageArray[chestI].size()) then
        nextSortedIndex = 1
        chestI = chestI + 1
      end
    end
  end
end

m.itemPull = function(self, item)
  if (self.inventory[item] ~= nil) then
    self.interface.pullItems(peripheral.getName(self.inventory[item][1].chest), self.inventory[item][1].slot)
  end
end

m.itemPush = function(self)
  for slot, item in pairs(self.interface.list()) do
    for i = 1, #self.storageArray do
      local storageChest = self.storageArray[i]
      local chestID = peripheral.getName(storageChest)
      local pushed = self.interface.pushItems(chestID, slot)
      if (pushed == item.count) then
        break
      end
    end
  end
end

m.processTasks = function(self)
  while true do
    local event = {os.pullEvent()}
    if (event[1] == "peripheral") then
      local chest = peripheral.wrap(event[2])
      table.insert(self.storageArray, chest)
      self:mapInventory()
      self:refreshList()
    elseif (event[1] == "peripheral_detach") then
      for i = 1, #self.storageArray do
        if (peripheral.getName(self.storageArray[i]) == event[2]) then
          table.remove(self.storageArray, i)
          self:mapInventory()
          self:refreshList()
          break
        end
      end
    end
  end
end

--## Runtime ##--

m.run = function(self)
  term.clear()
  term.setCursorPos(1,1)
  ui._timerID = os.startTimer(0)
  ui:run()
  
  -- parallel.waitForAny(
  --   function()
  --   end,
  --   function()
  --     self:processTasks()
  --   end
  -- )
end 

--## Constructor Method ##--

m.new = function(self) -- , t)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  --self.t = t
  return o
end

--return m

--## Main Runtime ##--

os.setComputerLabel("Storage " .. os.computerID())

local w, h = term.getSize()

inventoryManager = m:new()

local hbar1 = hbar:new("Capacity")
local button1 = button:newStatic("STORE")
local button2 = button:newStatic("SORT")
local search1 = searchbar:new()
local list1 = scrolllist:new()

hbar1:setUpdate(function()
  local used = 0
  for i, chest in ipairs(inventoryManager.storageArray) do  
    for slot, item in pairs(chest.list()) do
      used = used + 1
    end
  end
  hbar1:setVal(used)
end)

button1:setClick(function()
  inventoryManager:itemPush()
  inventoryManager:mapInventory()
  list1:setLines(inventoryManager:getInventoryList())
  ui:display(list1)
end)

button2:setClick(function()
  inventoryManager:consolidateInventory()
  inventoryManager:mapInventory()
end)

search1:setKeyboard(function(searchString)
  list1:filterLines(searchString)
  ui:display(list1)
end)

list1:setClick(function(lineItem)
  inventoryManager:itemPull(lineItem)
  inventoryManager:mapInventory()
  list1:setLines(inventoryManager:getInventoryList())
  ui:display(list1)
end)

inventoryManager.refreshList = function(self)
  inventoryManager:mapInventory()
  list1:setLines(inventoryManager:getInventoryList())
  ui:display(list1)
end

ui:add(hbar1, w - math.floor(1 * w / 4), 1, w - math.floor(3 * w / 4), 2)
ui:add(button1, 2, 1, 7, 1)
ui:add(button2, 10, 1, 6, 1)
ui:add(search1, 1, 2, math.floor(3 * w / 4), 1)
ui:add(list1, 1, 3, w, h - 2)

if (args[1] == "run") then
  inventoryManager:getPeripherals()
  while (not inventoryManager:hasChestsAssigned()) do
    inventoryManager:assignChests()
  end
  
  local total = 0
  for i, chest in ipairs(inventoryManager.storageArray) do
    total = total + inventoryManager.storageArray[i].size()
  end
  hbar1:setMinMax(0, total)

  inventoryManager:mapInventory()
  list1:setLines(inventoryManager:getInventoryList())
  inventoryManager:run()
elseif (args[1] == "test") then
  inventoryManager:getPeripherals()
  while (not inventoryManager:hasChestsAssigned()) do
    inventoryManager:assignChests()
  end
  inventoryManager:mapInventory()
  local free = inventoryManager:_getFreeSlot()
  print(peripheral.getName(free.chest) .. " / " .. free.slot)
end

return m