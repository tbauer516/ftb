local quarry = require("lib/quarry")

local m = {}

m.t = nil -- placeholder for networking module

m.taskQueue = {}
m.protocol = "command-v1"
m.protocolMulti = "command-multi-v1"

--## Variables to track state ##--

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

m.send = function(self, toID, genCommand, protocol)
	if protocol == nil then
		protocol = self.protocol
	end
	rednet.send(toID, genCommand, protocol)
end

m.sendMulti = function(self, toID, genCommandArray, protocol)
	if protocol == nil then
		protocol = self.protocolMulti
	end
	rednet.send(toID, genCommandArray, protocol)
end

m.broadcast = function(self, genCommand, protocol)
	if protocol == nil then
		protocol = self.protocol
	end
	rednet.broadcast(genCommand, protocol)
end

-- task params are arrays becuase "unpack" uses the index. can't be done with keys.
m.c = {
	NUKE = {
		priority = 1,
		han = function(self)
			error({ message = "program NUKE command received", code = 500 })
		end,
	},

	KILL = {
		priority = 1,
		han = function(self)
			self.taskQueue = {}
			error({ message = "task KILL command received", code = 400 })
		end,
	},

	BUST = {
		priority = 1,
		han = function(self)
			self.taskQueue = {}
		end,
	},

	SKIP = {
		priority = 1,
		han = function(self)
			error({ message = "task SKIP command received", code = 400 })
		end,
	},

	RESETLOC = {
		han = function(self)
			self.t:setLocFromGPS()
		end,
	},

	TIMEOUT = {},

	MOVE = {
		han = function(self, dir)
			self.t[dir](self.t)
		end,
	},

	SENDMOVE = {},

	CRUISETO = {
		han = function(self, targetLoc, alt)
			self.t:setCruise(alt)
			self.t:cruiseTo(targetLoc)
		end,
	},

	MOVETO = {
		han = function(self, targetLoc)
			self.t:moveTo(targetLoc)
		end,
	},

	MOVEHOME = {
		han = function(self)
			self.t:setCruise(math.max(self.t.curLoc.y, self.t.homeLoc.y) + 6)
			self.t:cruiseTo(self.t.homeLoc)
		end,
	},

	BLISTREQ = {
		han = function(self, senderID)
			local h = fs.open("blacklist/default.blist", "r")
			if h ~= nil then
				local text = h.readAll()
				if type(text) == "string" then
					local unserialized = textutils.unserialize(text)
					self:send(senderID, self.c.BLISTRES.gen(unserialized))
				end
				h.close()
			end
		end,
	},

	BLISTRES = {
		han = function(self, blacklist)
			local h = fs.open("blacklist/default.blist", "w")
			if h ~= nil then
				h.write(textutils.serialize(blacklist))
				h.close()
			end
		end,
	},

	CHECKFUEL = {
		han = function(self, dist)
			local enoughFuel, levelDifference = self.t:checkFuelGraceful(self.t:calcLocD(dist))
			local w, h
			if not enoughFuel then
				self.t:setStatus("FUEL 0")
				self.t:sendStatus("FUEL 0")
				w, h = term.getSize()
			end
			while not enoughFuel do
				term.setCursorPos(1, h - 1)
				term.write("Add fuel to slot 16...")
				term.setCursorPos(1, h)
				term.write(levelDifference * -1 .. " needed")
				os.startTimer(5)
				os.pullEvent("timer")
				enoughFuel, levelDifference = self.t:checkFuelGraceful(self.t:calcLocD(dist))
			end
		end,
	},

	MINE = {
		han = function(self, l, w)
			local quarryinstance = quarry:new(self.t, l, w)
			-- self.t:saveLoc(quarryinstance.initialLoc, quarryinstance.locFile)
			quarryinstance:start()
		end,
	},

	SETHOME = {
		han = function(self)
			self.t:setHome()
		end,
	},

	STATUSREQ = {
		priority = 1,
		han = function(self, senderID)
			self:send(senderID, self.c.STATUSRES.gen(self.t:getStatus()))
		end,
	},

	STATUSRES = {},

	CHECKREQ = {
		priority = 1,
		han = function(self, senderID)
			self:send(senderID, self.c.CHECKRES.gen(self.t:getStatus()))
		end,
	},

	CHECKRES = {},

	PAIRREQ = {
		han = function(self, senderID)
			if self.t.n.serverID ~= nil then
				return
			end
			print("Would you like to pair computer: " .. senderID .. "?")
			print("(y) yes, (n) no")
			local timerID = os.startTimer(30)
			while true do
				local event = { os.pullEvent() }
				if event[1] == "timer" and event[2] == timerID then
					self:send(senderID, self.c.PAIRRES.gen(false))
					break
				elseif event[1] == "key" then
					if event[2] == keys.y then
						self.t.n:setServerID(senderID)
						self:send(senderID, self.c.PAIRRES.gen(true, self.t:getStatus()))
						break
					else
						self:send(senderID, self.c.PAIRRES.gen(false))
						break
					end
				end
			end
			term.clear()
		end,
	},

	PAIRRES = {},

	UNPAIRREQ = {
		han = function(self, senderID)
			self.t.n:unsetServerID()
			self:send(senderID, self.c.UNPAIRRES.gen(true))
		end,
	},

	UNPAIRRES = {},
}

--## Helper Functions ##--

--## Constructor Method ##--

m.new = function(self, t)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	self.t = t

	for commandName, commandProps in pairs(self.c) do
		if commandProps.gen == nil then
			commandProps.gen = function(...)
				return { commandName, { ... } }
			end
		end
		if commandProps.han == nil then
			commandProps.han = function()
				error({ message = commandName .. " handler not implemented", code = 500 })
			end
		end
	end

	return o
end

return m
