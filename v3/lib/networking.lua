local m = {}

m.modem = nil
m.gps = nil
m.serverID = nil

--## Request Constants ##--
m.request = {
  availability = "Requesting Work",
  available = "Approve Work",
  instructions = "Work Instructions",
  locUpdate = "Location Update",
  completed = "Work Complete",
  availabilityForCoords = "Waiting to send coords",
  availableForCoords = "Ready to send coords",
  shareCoordinates = "Sharing Coordinates",
}

--## Helper Networking Functions ##--

m.initModem = function(self)
    local modem = peripheral.find("modem")
    if (modem) then
      self.modem = modem

      for i, v in ipairs(peripheral.getNames()) do
        if (peripheral.getType(v) == "modem") then
          rednet.open(v)
        end
      end
    end
  end
  
m.checkModem = function(self)
  if (self.modem ~= nil) then
    return true
  end
  return false
end

m.getModem = function(self)
  return self.modem
end

m.initGPS = function(self)
  local result = {gps.locate()}
  if (#result > 0) then
    self.gps = true
  else
    self.gps = false
  end
end

m.checkGPS = function(self)
  if (not self:checkModem()) then
    error("No modem is attached")
  end

  return self.gps
end

m.getLoc = function(self)
  local result = {gps.locate()}
  return {x = result[1], y = result[2], z = result[3]}
end

--## Client-Server Related Functions ##--

--## Client Functions ##--

m.waitForServerJob = function(self)
  while true do
    local result = {rednet.receive()}
    if (result[3] == self.request.availability) then --sProtocol
      self.serverID = result[1]
      local delay = tonumber(result[2])
      rednet.send(self.serverID, self.request.available, self.request.available)
      local result = {rednet.receive(self.request.instructions, delay)}
      if (#result == 0) then
        return { { "TIMEOUT", { "No instructions received" }} }
      end
      return result[2]
    end
  end
end

m.sendLoc = function(self, locObj)
  -- if (self.serverID ~= nil) then
  --   rednet.send(self.serverID, locObj, self.request.locUpdate)
  -- else
  -- end
  rednet.broadcast(locObj, self.request.locUpdate)
end

--## Server Functions ##--

m.getAvailable = function(self, delay)
  if (delay == nil) then delay = 5 end
  rednet.broadcast(delay, self.request.availability)
  local clients = {}
  local timerID = os.startTimer(3)
  
  while true do
    local event = {os.pullEvent()}
    if (event[1] == "timer") then
      break
    elseif (event[1] == "rednet_message" and event[4] == self.request.available) then
      -- local result = {rednet.receive(self.request.available)}
      os.cancelTimer(timerID)
      clients[#clients + 1] = event[2]
      timerID = os.startTimer(3)
    end
  end

  return clients
end

m.sendInstructionsForMine = function(self, clients, coords)
  for i=1,#coords do
    local command = { { "CRUISE", { i } } }

    command[#command + 1] = { "MOVE", { coords[i] } }
    command[#command + 1] = { "MINE", {coords[i].l, coords[i].w, "ftb"} }

    rednet.send(clients[i], command, self.request.instructions)
  end
  if (#clients - #coords > 0) then
    for i=#clients,#clients-#coords,-1 do
      local command = { { "ABORT", {} } } 
      rednet.send(clients[i], command, self.request.instructions)
    end
  end
end

m.listenForUpdates = function(self, clients, dispFunc)
  while #clients > 0 do
    local result = {rednet.receive()}
    if (result[3] == self.request.locUpdate) then
      for i=1,#clients do
        if (result[1] == clients[i]) then
          dispFunc(i, clients[i], result[2])
          -- term.setCursorPos(1, i)
          -- term.clearLine()
          -- term.write(clients[i] .. ": { x="..result[2].x..", y="..result[2].y..", z="..result[2].z..", d="..result[2].d..", s="..result[2].s.." }")
        end
      end
    elseif (result[3] == self.request.completed) then
      for i=1,#clients do
        if (result[1] == clients[i]) then
          clients[i] = nil
        end
      end
    end
  end
  term.clear()
  term.setCursorPos(1,1)
end

m.listenForUpdatesStandalone = function(self, dispFunc)
  while true do
    local result = {rednet.receive(self.request.locUpdate)}
    dispFunc(result[1], result[2])
  end
  term.clear()
  term.setCursorPos(1,1)
end

m.getAvailableTablet = function(self)
  rednet.broadcast(delay, self.request.availabilityForCoords)
  local result = {rednet.receive(self.request.availableForCoords, 10)}
  if (#result == 0) then
    return nil
  end
  return result[1]
end

m.listenForCoordinates = function(self, tabletID)
  local timerID = os.startTimer(120)
  local coord1 = nil
  local coord2 = nil

  while true do
    local result = {os.pullEvent()}
    if (result[1] == "timer" and result[2] == timerID) then
      return {}
    elseif (result[1] == "rednet_message" and result[2] == tabletID) then
      coord1 = result[3]
      os.cancelTimer(timerID)
      break
    end
  end
  timerID = os.startTimer(60)
  while true do
    local result = {os.pullEvent()}
    if (result[1] == "timer" and result[2] == timerID) then
      return {}
    elseif (result[1] == "rednet_message" and result[2] == tabletID) then
      coord2 = result[3]
      os.cancelTimer(timerID)
      break
    end
  end
  -- if (#coord1 == 0 or #coord2 == 0) then
  --   return {}
  -- end

  return {coord1, coord2}
end

--## Tablet Functions ##--

m.waitToSendAvailability = function(self)
  local result = {rednet.receive(self.request.availabilityForCoords)}
  self.serverID = result[1]
  rednet.send(self.serverID, "", self.request.availableForCoords)
end

m.getCoords = function(self)
  term.clear()
  term.setCursorPos(1,1)
  term.write("Please press SHIFT to send coordinate")
  local coords = {}
  for i=1,2 do
    local result = {os.pullEvent("key")}
    if (result[2] == 42) then
      local loc = {gps.locate()}
      loc[1] = math.floor(loc[1])
      loc[2] = math.floor(loc[2]) - 1
      loc[3] = math.floor(loc[3])
      term.setCursorPos(1,i + 1)
      term.write("{"..loc[1]..","..loc[2]..","..loc[3].."}")
      coords[#coords + 1] = loc
    else
      i = i - 1
    end
  end
  term.clear()
  return coords
end

m.sendCoords = function(self)
  local coords = self:getCoords()
  rednet.send(self.serverID, coords[1], self.request.shareCoordinates)
  rednet.send(self.serverID, coords[2], self.request.shareCoordinates)
end

m.sendInstructionsForMoveHome = function(self, clients, coords)
  for i=1,math.min(#clients,4) do
    local command = { { "CRUISE", { i } } }

    command[#command + 1] = { "MOVE", { coords[i] } }
    command[#command + 1] = { "SETHOME", {} }

    rednet.send(clients[i], command, self.request.instructions)
  end
end

--## Constructor Method ##--

m.new = function(self)
  local o = {}
  setmetatable(o, self)
  self.__index = self

  self:initModem()
  self:initGPS()

  return o
end

return m