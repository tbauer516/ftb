local taskhandler = require("lib/taskhandler"):new()

local args = { ... }
local isMaster = true
if args[1] ~= "master" then
	isMaster = false
end

local modem = nil
local badgeProtocol = "badge-protocol"

local getModem = function()
	return peripheral.find("modem", function(name, modem)
		if modem.isWireless() then
			rednet.open(name)
			return true
		end
		return false
	end)
end

local getMonitors = function()
	return peripheral.find("monitor")
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
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2] } })
	end,
}

badge.handlers = {
	["badge-satellite-respond-validation"] = function(self, senderID)
		rednet.send(senderID, { "satellite-badge-receive-verification", {} }, badgeProtocol)
	end,
	["badge-master-add-master"] = function(self, senderID)
		self.master = senderID
		-- self:saveMaster()
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
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2] } })
	end,
	["key_up"] = function(self, keyID)
		if keyID == keys.a then
			taskhandler:queueTask({ "master-badge-add-badge", {} })
		end
	end,
}

master.handlers = {
	["master-satellite-add-satellite"] = function(self, senderID, params)
		local securityLevel = params[1]
		local location = params[2]
		local satelliteData = { sec = securityLevel, loc = { x = location[1], y = location[2], z = location[3] } }
		self.satellites[senderID] = satelliteData
		self:saveSatellites()
		rednet.send(senderID, { "satellite-master-confirm-master", {} }, badgeProtocol)
	end,
	["master-satellite-return-badge-list"] = function(self, senderID)
		if self.satellites[senderID] ~= nil then
			local badgeList = {}
			for badgeID, _ in pairs(self.badges) do
				badgeList[badgeID] = true
			end
			rednet.send(senderID, { "satellite-master-receive-badge-list", { badgeList } }, badgeProtocol)
		end
	end,
	["master-satellite-validate-badge"] = function(self, senderID, params)
		local badgeID = params[1]
		local isAuthorized = self.badges[badgeID] <= self.satellites[senderID].sec
		rednet.send(senderID, { "satellite-master-badge-validated", { isAuthorized } }, badgeProtocol)
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
satellite.monitors = {}
satellite.modemSet = {}
satellite.timers = {}

satellite.dispatchers = {
	["redstone"] = function()
		local hasInput = false
		for _, side in ipairs({ "front", "back", "left", "right" }) do
			if redstone.getInput(side) then
				hasInput = true
				break
			end
		end
		if hasInput and redstone.getInput("top") == false then
			taskhandler:queueTask({ "satellite-master-get-badge-list", {} })
		end
	end,
	["monitor_touch"] = function(self, side, x, y)
		taskhandler:queueTask({ "satellite-master-get-badge-list", {} })
	end,
	["modem_message"] = function(self, side, channel, replychannel, message, distance)
		if message.nMessageID == nil then
			taskhandler:queueTask({ message[1], { replychannel, message[2], distance } })
		else
			taskhandler:queueTask({ message.message[1], { replychannel, message.message[2], distance } })
		end
	end,
	["rednet_message"] = function(self, senderID, message, protocol)
		if protocol ~= badgeProtocol then
			return
		end
		taskhandler:queueTask({ message[1], { senderID, message[2] } })
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
	["satellite-master-request-add"] = function(self, senderID, securityLevel, location)
		rednet.send(senderID, { "master-satellite-add-satellite", { securityLevel, location } }, badgeProtocol)
	end,
	["satellite-master-confirm-master"] = function(self, senderID)
		self.master = senderID
		self:saveMaster()
	end,
	["satellite-master-get-badge-list"] = function(self)
		rednet.send(self.master, { "master-satellite-return-badge-list", {} }, badgeProtocol)
	end,
	["satellite-master-receive-badge-list"] = function(self, senderID, params)
		local badges = params[1]
		for badgeID, _ in pairs(badges) do
			rednet.send(badgeID, { "badge-satellite-respond-validation", {} }, badgeProtocol)
		end
	end,
	["satellite-badge-receive-verification"] = function(self, senderID, task, distance)
		if distance ~= nil then
			if distance < 5.3 then
				self.modemSet[senderID] = true
			end
		else
			if self.modemSet[senderID] ~= nil then
				self.modemSet[senderID] = nil
				rednet.send(self.master, { "master-satellite-validate-badge", { senderID } }, badgeProtocol)
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
		for timerID, instruction in pairs(self.timers) do
			if instruction[1] == "satellite-shut-door" then
				os.cancelTimer(timerID)
				self.timers[timerID] = nil
			end
		end
		local doorTimer = os.startTimer(1.5)
		self.timers[doorTimer] = { "satellite-shut-door", {} }
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

modem = getModem()
if modem == nil then
	error("No modem found")
end

local runtime = nil
if pocket ~= nil then
	runtime = badge:new()
	badge:loadMaster()
elseif isMaster then
	runtime = master:new()
	master:loadSatellites()
	master:loadBadges()
else
	runtime = satellite:new()
	satellite:loadMaster()
end
runtime.modem = modem

display()

taskhandler:run(runtime.dispatchers, runtime.handlers, runtime)
