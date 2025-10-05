local command = require("lib/commands"):new()
local uiMain = require("ui/main")
local n = require("lib/networking"):new()

local args = { ... }
rednet.open("back")

local turtFile = "managed-turtles.txt"

local turtManager = {}

turtManager.turtles = {}
turtManager.status = {}
turtManager.count = 0
turtManager.min = nil
turtManager.max = nil

turtManager.loadTurtles = function(self)
	if not fs.exists(turtFile) then
		return
	end
	local h = fs.open(turtFile, "r")
	local tempTurtles = nil
	if h ~= nil then
		local text = h.readAll()
		if type(text) == "string" then
			tempTurtles = textutils.unserialize(text)
		end
		h.close()
	end
	if type(tempTurtles) ~= "table" then
		return
	end
	for turtleID, _ in pairs(tempTurtles) do
		self:addTurtle(turtleID)
	end
end

turtManager.saveTurtles = function(self)
	local h = fs.open(turtFile, "w")
	if h ~= nil then
		h.write(textutils.serialize(self.turtles))
		h.close()
	end
end

turtManager.addTurtle = function(self, id)
	if self.turtles[id] == nil then
		self.turtles[id] = true
		self.status[id] = {
			id = id,
			loc = nil,
			fuel = nil,
			inventory = {},
			inventoryTotal = nil,
			status = "OFFLINE",
		}
		self.count = self.count + 1
		if self.min == nil or id < self.min then
			self.min = id
		end
		if self.max == nil or id > self.max then
			self.max = id
		end
		self:saveTurtles()
	end
end

turtManager.removeTurtle = function(self, id)
	if self.turtles[id] ~= nil then
		self.turtles[id] = nil
		self.status[id] = nil
		if self.count > 1 and self.min == id then
			for i = self.min, self.max do
				if self.turtles[i] ~= nil then
					self.min = i
					break
				end
			end
		end
		if self.count > 1 and self.max == id then
			for i = self.max, self.min, -1 do
				if self.turtles[i] ~= nil then
					self.max = i
					break
				end
			end
		end
		if self.count == 1 then
			self.min = nil
			self.max = nil
		end
		self.count = self.count - 1
		self:saveTurtles()
	end
end

turtManager.updateStatus = function(self, id, status)
	if self.status[id] ~= nil then
		self.status[id] = status
	end
end

turtManager.getTurtles = function(self)
	return self.status
end

turtManager.getTurtle = function(self, id)
	return self.status[id]
end

turtManager.getCount = function(self)
	return self.count
end

turtManager.forEach = function(self, func)
	local index = 1
	for i = self.min, self.max do
		if self.status[i] ~= nil then
			func(index, self.status[i])
			index = index + 1
		end
	end
end

turtManager.new = function(self)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

local handleClick = function(main, x, y, buttonPressed)
	for cardIndex, card in pairs(main.body.elem) do
		if card.subPage.win.isVisible() then
			card.subPage:click(x, y, buttonPressed)
			return
		end
	end
	main:click(x, y, buttonPressed)
end

local handleScroll = function(main, dir, x, y)
	local w, h = main.body.win.getSize()
	local cardCount = main.turtleManager:getCount()
	local rowCount = math.ceil(cardCount / 3)
	local lineCount = (rowCount * 3) + 1
	if
		not main:hasOpenSubPage()
		and main.scroll + dir >= 0
		and lineCount - h > 0
		and main.scroll + dir <= lineCount - h
	then
		main.scroll = main.scroll + dir
		main.body.win.clear()
		main.body:render()
		-- main.body.win.setCursorPos(w - 1, h)
		-- main.body.win.write(main.scroll)
	end
end

--## Init ##--

local turtleManager = turtManager:new()
turtleManager:loadTurtles()

--## UI Section ##--

local w, h = term.getSize()
local main = uiMain:new(turtleManager)

main.win.setVisible(true)

for turtIndex, _ in pairs(turtleManager:getTurtles()) do
	main.body:add(turtIndex)
	command:send(turtIndex, command.c.CHECKREQ.gen())
end

--## Event Handlers ##--

command.c.PAIRRES.han = function(self, toPair, status, id)
	if toPair then
		turtleManager:addTurtle(id)
		turtleManager:updateStatus(id, status)
		main.body:add(id)
	end
end

command.c.UNPAIRRES.han = function(self, isUnpaired, id)
	turtleManager:removeTurtle(id)
end

command.c.CHECKRES.han = function(self, status, id)
	turtleManager:updateStatus(id, status)
	for elemID, elem in pairs(main.body.elem) do
		if id == elem.id then
			main.body:update(status)
			return
		end
	end
	main.body:add(id)
end

command.c.STATUSRES.han = function(self, status, id)
	turtleManager:updateStatus(id, status)
	main.body:update(status)
end

command.c.SENDMOVE.han = function(self, id, key)
	local instructions = {
		[keys.w] = "moveF",
		[keys.s] = "moveB",
		[keys.a] = "moveL",
		[keys.d] = "moveR",
		[keys.space] = "moveU",
		[keys.leftShift] = "moveD",
	}
	if instructions[key] ~= nil then
		command:send(id, command.c.MOVE.gen(instructions[key]))
	end
end

--## Main Runtime ##--

local taskHandler = function()
	while true do
		os.pullEvent("tablet_task")
		while #command.taskQueue > 0 do
			local message = table.remove(command.taskQueue, 1)
			local senderID = message[1]
			local params = message[2]
			local proto = message[3]
			local task = params[1]
			local taskDetails = params[2]
			table.insert(taskDetails, senderID)

			if command.c[task] ~= nil then
				command.c[task].han(command, unpack(taskDetails))
			end
		end
	end
end

local dispatcher = function()
	while true do
		local event = { os.pullEvent() }
		local look = {
			["rednet_message"] = function(senderID, params, proto)
				if proto == command.protocol then
					if command.c[params[1]] ~= nil and command.c[params[1]].priority == 1 then
						command.c[params[1]].han(command, unpack(params[2]))
					else
						table.insert(command.taskQueue, { senderID, params, proto })
						os.queueEvent("tablet_task")
					end
				elseif proto == n.statusProtocol then
					table.insert(command.taskQueue, { senderID, command.c.STATUSRES.gen(params), proto })
					os.queueEvent("tablet_task")
				end
			end,
			["mouse_click"] = function(buttonPressed, xCoord, yCoord)
				handleClick(main, xCoord, yCoord, buttonPressed)
			end,
			["mouse_scroll"] = function(dir, xCoord, yCoord)
				handleScroll(main, dir, xCoord, yCoord)
			end,
			["key"] = function(keyID, heldDown)
				if keyID == keys.delete then
					error({ message = "physical KILLswitch pressed", code = 500 })
				elseif keyID == keys.t then
					command:send(27, command.c.TESTMODEM.gen())
				elseif not heldDown then
					for elemID, elem in pairs(main.body.elem) do
						if elem.subPage.win.isVisible() and elem.subPage.controlling then
							local turtleID = elem.subPage.id
							table.insert(
								command.taskQueue,
								{ os.computerID(), command.c.SENDMOVE.gen(turtleID, keyID) }
							)
							os.queueEvent("tablet_task")
						end
					end
				end
			end,
		}
		if look[event[1]] ~= nil then
			look[event[1]](table.unpack(event, 2))
		end
	end
end

while true do
	local success, exception = pcall(function()
		parallel.waitForAny(dispatcher, taskHandler)
	end)
	if not success and exception ~= nil then
		if exception.code ~= nil then
			if exception.code ~= 500 then
				print(exception.message)
			else
				error(exception.message)
			end
		else
			error(exception)
		end
	end
end
