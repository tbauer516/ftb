local taskhandler = require("lib/taskhandler"):new()

local args = { ... }
if #args < 1 then
	term.clear()
	term.setCursorPos(1, 1)
	print("rfidmanager badge     -> run as badge on tablet")
	print("rfidmanager satellite -> run as satellite near door")
	print("rfidmanager master    -> run as master")
	print()
	print("for satellite, you need:")
	print("  1 wireless modem, 1 wired modem separate to master")
	print("  1 wired modem to a block modem with a wireless modem")
	print("  The computer is below the door and this block modem is")
	print("  diagonally SE from that computer.")
	print("  [C][ ]")
	print("  [ ][M]")
	print("for master, you need 1 wireless and 1 wired modem connected to every other satellite")
	error()
end

local isMaster = false
if args[1] == "master" then
	isMaster = true
end

local badgeProtocol = "badge-protocol"
local mType = {
	modem = 1,
	rednet = 2,
}
local rfidDistance = 4.1

local getWirelessModem = function()
	return peripheral.find("modem", function(name, modem)
		if modem.isWireless() and not string.find(name, "modem") then
			rednet.open(name)
			return true
		end
		return false
	end)
end

local getWiredComputerModem = function()
	return peripheral.find("modem", function(name, modem)
		if not modem.isWireless() and modem.getNamesRemote ~= nil then
			for _, remoteName in ipairs(modem.getNamesRemote()) do
				if string.find(remoteName, "modem") then
					return false
				end
			end
			modem.open(os.getComputerID())
			return true
		end
		return false
	end)
end

local getWiredBlockModem = function()
	return peripheral.find("modem", function(name, modem)
		if modem.isWireless() and string.find(name, "modem") then
			return true
		end
		return false
	end)
end

local saveItems = function(itemPath, items)
	local h = fs.open(itemPath, "w")
	if h ~= nil then
		h.write(textutils.serialize(items))
		h.close()
	end
end

local loadItems = function(itemPath)
	local h = fs.open(itemPath, "r")
	if h ~= nil then
		local text = h.readAll()
		h.close()
		if type(text) == "string" then
			local obj = textutils.unserialize(text)
			return obj
		end
	end
	return nil
end

local display = function()
	local runAs = "master"
	if not isMaster then
		runAs = "satellite"
	end
	term.clear()
	term.setCursorPos(1, 1)
	term.write("Running ID Manager as - " .. runAs)
	term.setCursorPos(1, 2)
	if isMaster then
		term.write("(A) add badge\n")
	end
end

--## Instance Definitions ##--

local badge = {}

badge.master = nil
badge.masterPath = "master.txt"

badge.dispatchers = {
	["modem_message"] = function(self, side, channel, replychannel, message, distance) end,
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2], mType.rednet } })
	end,
	["timer"] = function(self, timerID)
		taskhandler:queueTask({ "badge-satellite-send-proximity-query", { self.master } })
		os.startTimer(0.33)
	end,
}

badge.handlers = {
	["badge-satellite-respond-verification"] = function(self, senderID, params, messageType)
		if messageType ~= mType.rednet then
			return
		end
		rednet.send(senderID, { "satellite-badge-receive-verification", {} }, badgeProtocol)
	end,
	["badge-satellite-send-proximity-query"] = function(self, senderID)
		if senderID ~= nil then
			self.modemWireless.transmit(senderID, os.computerID(), { "satellite-badge-receive-proximity-query", {} })
		end
	end,
	["badge-master-add-master"] = function(self, senderID, params, messageType)
		if messageType ~= mType.rednet then
			return
		end
		self.master = senderID
		self:saveMaster()
		rednet.send(senderID, { "master-badge-confirm-badge", {} }, badgeProtocol)
	end,
}

badge.saveMaster = function(self)
	saveItems(self.masterPath, self.master)
end

badge.loadMaster = function(self)
	local master = loadItems(self.masterPath)
	if master ~= nil and type(master) == "number" then
		self.master = master
	end
end

local master = {}

master.badges = {}
master.badgePath = "badges.txt"
master.satellites = {}
master.satellitePath = "satellites.txt"
master.timers = {}

master.dispatchers = {
	["modem_message"] = function(self, side, channel, replychannel, message, distance)
		if message.nMessageID == nil then
			if side == peripheral.getName(self.modemWired) then
				taskhandler:queueTask({ message[1], { replychannel, message[2], distance, mType.modem } })
			end
		else
			taskhandler:queueTask({ message.message[1], { replychannel, message.message[2], distance, mType.modem } })
		end
	end,
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2], mType.rednet } })
	end,
	["key_up"] = function(self, keyID)
		if keyID == keys.a then
			taskhandler:queueTask({ "master-badge-add-badge", {} })
		end
	end,
}

master.handlers = {
	["master-satellite-add-satellite"] = function(self, satelliteID, params)
		local securityLevel = params[1]
		local location = params[2]
		local satelliteData = { sec = securityLevel, loc = { x = location[1], y = location[2], z = location[3] } }
		self.satellites[satelliteID] = satelliteData
		self:saveSatellites()
		self.modemWired.transmit(satelliteID, os.getComputerID(), { "satellite-master-confirm-master", {} })
	end,
	["master-satellite-validate-badge"] = function(self, satelliteID, params)
		local badgeID = params[1]
		local isAuthorized = self.badges[badgeID] <= self.satellites[satelliteID].sec
		self.modemWired.transmit(satelliteID, os.computerID(), { "satellite-master-badge-validated", { isAuthorized } })
	end,
	["master-badge-add-badge"] = function(self)
		local newBadge = nil
		local newBadgeSecurity = nil
		while type(newBadge) ~= "number" do
			term.setCursorPos(1, 5)
			term.clearLine()
			term.write("ID Number: ")
			newBadge = tonumber(read())
		end
		while type(newBadgeSecurity) ~= "number" or newBadgeSecurity < 1 or newBadgeSecurity > 5 do
			term.setCursorPos(1, 7)
			term.clearLine()
			term.write("Security level: ")
			newBadgeSecurity = tonumber(read())
		end
		self.badges[newBadge] = newBadgeSecurity
		rednet.send(newBadge, { "badge-master-add-master", {} }, badgeProtocol)
		local timerID = os.startTimer(3)
		self.timers[timerID] = newBadge
		display()
	end,
	["master-badge-confirm-badge"] = function(self, senderID)
		self:saveBadges()
	end,
	["master-confirm-badge-timeout"] = function(self, timerID)
		self.badges[self.timers[timerID]] = nil
		self.timers[timerID] = nil
	end,
}

master.saveBadges = function(self)
	saveItems(self.badgePath, self.badges)
end

master.loadBadges = function(self)
	local badges = loadItems(self.badgePath)
	if badges ~= nil and type(badges) == "table" then
		self.badges = badges
	end
end

master.saveSatellites = function(self)
	saveItems(self.satellitePath, self.satellites)
end

master.loadSatellites = function(self)
	local satellites = loadItems(self.satellitePath)
	if satellites ~= nil and type(satellites) == "table" then
		self.satellites = satellites
	end
end

local satellite = {}

satellite.master = nil
satellite.masterPath = "master.txt"
satellite.modemSet = {}
satellite.timers = {}
satellite.badgeQueue = {}

satellite.dispatchers = {
	["modem_message"] = function(self, side, channel, replychannel, message, distance)
		if message.nMessageID == nil then
			taskhandler:queueTask({ message[1], { replychannel, message[2], distance, mType.modem, side } })
		elseif self.handlers[message.message[1]] ~= nil then
			taskhandler:queueTask({
				message.message[1],
				{ replychannel, message.message[2], distance, mType.modem, side },
			})
		end
	end,
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2], protocol, mType.rednet } })
	end,
	["timer"] = function(self, timerID)
		if self.timers[timerID] ~= nil then
			taskhandler:queueTask(self.timers[timerID])
		end
	end,
}

satellite.handlers = {
	["satellite-shut-door"] = function()
		redstone.setOutput("top", false)
	end,
	["satellite-master-request-add"] = function(self, newMasterID, securityLevel, location)
		self.modemWired.transmit(
			newMasterID,
			os.getComputerID(),
			{ "master-satellite-add-satellite", { securityLevel, location } }
		)
	end,
	["satellite-master-confirm-master"] = function(self, masterID)
		self.master = masterID
		self:saveMaster()
	end,
	["satellite-badge-receive-proximity-query"] = function(self, senderID, task, distance, messageType, side)
		if self.badgeQueue[senderID] == nil then
			self.badgeQueue[senderID] = {}
		end
		if distance ~= nil and distance < 2 + rfidDistance then
			self.badgeQueue[senderID][side] = distance
			local dist1 = self.badgeQueue[senderID][self.modemLocationName]
			local dist2 = self.badgeQueue[senderID][self.modemWirelessName]
			if dist1 ~= nil and dist2 ~= nil and (dist1 + dist2) / 2 < rfidDistance then
				rednet.send(senderID, { "badge-satellite-respond-verification", {} }, badgeProtocol)
			else
				taskhandler:queueTask({ "satellite-shut-door", {} })
			end
		else
			self.badgeQueue[senderID] = {}
			taskhandler:queueTask({ "satellite-shut-door", {} })
		end
	end,
	["satellite-badge-receive-verification"] = function(self, senderID, task, distance, messageType)
		if messageType == mType.modem then
			self.modemSet[senderID] = true
		elseif messageType == mType.rednet then
			if self.modemSet[senderID] ~= nil then
				self.modemSet[senderID] = nil
				self.modemWired.transmit(
					self.master,
					os.getComputerID(),
					{ "master-satellite-validate-badge", { senderID } }
				)
			end
		end
	end,
	["satellite-master-badge-validated"] = function(self, senderID, params)
		local isAuthorized = params[1]
		if isAuthorized then
			taskhandler:queueTask({ "satellite-open-door", {} })
		end
	end,
	["satellite-open-door"] = function(self)
		redstone.setOutput("top", true)
	end,
}

satellite.assignMaster = function(self)
	local newMaster = nil
	local securityLevel = nil
	term.clear()
	term.setCursorPos(1, 1)
	term.write("No master server found...")
	while type(newMaster) ~= "number" do
		term.setCursorPos(1, 3)
		term.clearLine()
		term.write("Enter master server ID: ")
		newMaster = tonumber(read())
	end
	while type(securityLevel) ~= "number" or securityLevel < 1 or securityLevel > 5 do
		term.setCursorPos(1, 5)
		term.clearLine()
		term.write("Enter security level: ")
		securityLevel = tonumber(read())
	end
	local location = { gps.locate() }
	self.master = newMaster

	taskhandler:queueTask({ "satellite-master-request-add", { newMaster, securityLevel, location } })
end

satellite.saveMaster = function(self)
	saveItems(self.masterPath, self.master)
end

satellite.loadMaster = function(self)
	local master = loadItems(self.masterPath)
	if master ~= nil and type(master) == "number" then
		self.master = master
	else
		self:assignMaster()
	end
end

badge.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	return o
end

master.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	return o
end

satellite.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	return o
end

--## Main Runtime ##--

local runtime = nil
if pocket ~= nil then
	runtime = badge:new()
	runtime:loadMaster()
	runtime.modemWireless = getWirelessModem()
	os.startTimer(1)
elseif isMaster then
	runtime = master:new()
	runtime:loadSatellites()
	runtime:loadBadges()
	runtime.modemWired = getWiredComputerModem()
	runtime.modemWireless = getWirelessModem()
else
	runtime = satellite:new()
	runtime:loadMaster()
	runtime.modemWired = getWiredComputerModem()
	runtime.modemLocation = getWiredBlockModem()
	runtime.modemLocationName = peripheral.getName(runtime.modemLocation)
	runtime.modemWireless = getWirelessModem()
	runtime.modemWirelessName = peripheral.getName(runtime.modemWireless)
	---@diagnostic disable-next-line: undefined-field
	runtime.modemLocation.open(runtime.master)
	---@diagnostic disable-next-line: undefined-field
	runtime.modemWireless.open(runtime.master)
end

display()

taskhandler:run(runtime.dispatchers, runtime.handlers, runtime)
