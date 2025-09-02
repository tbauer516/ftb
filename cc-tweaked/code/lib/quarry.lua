local m = {}

--## Variables to track state ##--
m.t = nil -- placeholder for "t" module to go

m.bedrockDangerZone = 4 -- not y-choord, amount of buffer
m.surfaceBuffer = 5
m.junkSlot = 15
m.junkLimit = 10

m.bedrockLoc = nil
m.blacklist = {}
m.minY = 0
m.maxY = 0

m.quarryLength = 1
m.quarryWidth = 1

m.blocksMined = 0

m.initialLoc = nil
m.locFile = "initial.loc"

--## Helper Functions ##--

m.setQuarrySize = function(self, length, width)
	self.quarryLength = length
	self.quarryWidth = width
end

m.mineBedrockColumn = function(self)
	local columnTop = self.t:getLoc()
	local diggingDown = true
	while diggingDown do
		while not self.t:suckF() do
			self:checkStorage()
		end
		if self.t:scanF() then
			self.t:digF()
		end
		while not self.t:suckD() do
			self:checkStorage()
		end
		diggingDown = self.t:mineD()
	end
	local bottomLoc = self.t:getLoc()
	if bottomLoc.y < self.maxY then
		self.maxY = bottomLoc.y
		self.minY = self.maxY
	end
	if bottomLoc.y > self.minY then
		self.minY = bottomLoc.y
	end
	columnTop.y = self.maxY + self.bedrockDangerZone
	self.t:moveTo(columnTop)
end

m.burrow = function(self)
	turtle.select(self.junkSlot)
	self.t:mineD()
	self.t:mineD()
	turtle.placeUp()

	local diggingDown = true
	while diggingDown do
		while not self.t:suckD() do
			self:consolidate()
			if self:storageFull() then
				local burrowLoc = self.t:getLoc()
				self.t:moveTo(self.initialLoc)
				self:dumpItems()
				self.t:mineD()
				self.t:mineD()
				turtle.select(self.junkSlot)
				turtle.placeUp()
				self.t:moveTo(burrowLoc)
			end
		end
		diggingDown = self.t:mineD()
	end
	self.bedrockLoc = self.t:getLoc()
	self.minY = self.bedrockLoc.y + self.bedrockDangerZone
	self.maxY = self.bedrockLoc.y
	self.bedrockLoc.y = self.bedrockLoc.y + self.bedrockDangerZone
	self.t:moveTo(self.bedrockLoc)
end

-- don't want to hit anything on the way up
-- move back 1 in case chest above/below, move down a level
-- move to column of start, then move up
m.returnToSurface = function(self)
	self.t:setStatus("Returning to surface")
	turtle.select(self.junkSlot)
	self.t.maxLoc = self.t:getLoc()
	local vertical = self.t:copyLoc(self.bedrockLoc)
	if self.t:getLoc().y < self.initialLoc.y - self.surfaceBuffer then
		vertical.y = math.max(self.bedrockLoc.y, self.t.maxLoc.y - 3)
	else
		vertical.y = self.t:getLoc().y
	end
	self.t:checkFuel(self.t.homeLoc)
	self.t:moveTo(vertical)

	self.t:moveTo(self.initialLoc)

	turtle.select(self.junkSlot)
	turtle.placeDown()
	turtle.select(self.junkSlot)

	self.t:setStatus("Moving to home")
	self.t:cruiseTo(self.t.homeLoc)
end

m.returnToMine = function(self)
	self.t:setStatus("Returning to mine location")
	self.t:cruiseTo(self.initialLoc)

	turtle.select(self.junkSlot)
	self.t:mineD()
	self.t:mineD()
	turtle.select(self.junkSlot)
	turtle.placeUp()

	self.t:checkFuel(self.t.maxLoc)
	local vertical = self.t:copyLoc(self.bedrockLoc)
	vertical.y = math.max(self.bedrockLoc.y, self.t.maxLoc.y - 3)
	self.t:moveTo(vertical)

	self.t:setStatus("Tunneling to previous location")
	local belowMaxLoc = self.t:copyLoc(self.t.maxLoc)
	belowMaxLoc.y = vertical.y
	belowMaxLoc.d = vertical.d
	self.t:moveTo(belowMaxLoc)
	self.t:moveTo(self.t.maxLoc)
	self.t:setStatus("Mining")
end

m.consolidateDropDir = function(self, dropFunc)
	for i = 1, self.junkSlot - 1 do
		local details = turtle.getItemDetail(i)
		if details ~= nil then
			for j = 1, #self.blacklist do
				if details["name"] == self.blacklist[j] then
					turtle.select(i)
					dropFunc()
				end
			end
			if turtle.getItemCount(i) > 0 then
				turtle.transferTo(self.t.fuelSlot)
			end
		end
	end
	local count = turtle.getItemCount(self.junkSlot)
	if count > self.junkLimit then
		turtle.select(self.junkSlot)
		dropFunc(count - self.junkLimit)
	end
	turtle.select(self.junkSlot)
end

m.consolidate = function(self)
	self:consolidateDropDir(turtle.dropDown)
end

m.dumpItems = function(self)
	self:consolidate()
	for i = 1, self.junkSlot - 1 do
		turtle.select(i)
		self.blocksMined = self.blocksMined + turtle.getItemCount()
		turtle.drop()
	end
	turtle.select(self.junkSlot)
end

m.storageFull = function(self)
	return turtle.getItemCount(self.junkSlot - 1) > 0
end

m.checkStorage = function(self)
	if self:storageFull() then
		self:returnToSurface()
		self:dumpItems()
		self:returnToMine()
	end
end

--## Runtime Logic ##--

m.start = function(self)
	self.t:setStatus("Mining")
	local starttime = os.clock()
	local quarrysuccess, quarryvalue = pcall(function()
		self.t:checkFuel(self.t:calcLocD(500))
		self:burrow() -- gets us to bedrock + dangerzone

		local initialD = self.t:getLoc().d
		local wDir = 1

		if self.bedrockDangerZone > 0 then -- do bedrock pattern across plane and back to end up in initial position
			for planeI = 1, 2 do -- do the plane one direction, then do it again the other direction
				for rowI = 1, self.quarryWidth do -- inside this loop == done once per row
					for cellI = 1, self.quarryLength - 1 do -- inside this loop == done once per cell
						self:consolidate()
						self:mineBedrockColumn()
						while not self.t:suckF() do
							self:checkStorage()
						end
						self.t:mineF()
						self.t:checkFuel(self.t.homeLoc)
					end

					if rowI < self.quarryWidth then -- on every row but the last, turn around on the new row
						local originalDir = self.t:getLoc()
						self.t:turnTo((initialD + wDir) % 4)
						self:consolidate()
						self:mineBedrockColumn()
						while not self.t:suckF() do
							self:checkStorage()
						end
						self.t:mineF()
						self.t:turnTo((originalDir.d + 2) % 4)
						self.t:checkFuel(self.t.homeLoc)
						self:checkStorage()
					end
				end

				self.t:turnTo((self.t:getLoc().d + 2) % 4)
				wDir = wDir * -1
			end
		end

		while true do -- inside this loop == done once per level
			for rowI = 1, self.quarryWidth do -- inside this loop == done once per row
				self:consolidate()

				for cellI = 1, self.quarryLength - 1 do -- inside this loop == done once per cell
					while not self.t:suckF() do
						self:checkStorage()
					end
					self.t:mineF()
					while not self.t:suckU() do
						self:checkStorage()
					end
					if self.t:scanU() then
						self.t:digU()
					end
					while not self.t:suckD() do
						self.t:moveB()
						self:checkStorage()
						self.t:moveF()
					end
					if self.t:scanD() then
						self.t:digD()
					end
					self.t:checkFuel(self.t.homeLoc)
					turtle.select(self.junkSlot)
					self:checkStorage()
				end

				if rowI < self.quarryWidth then -- on every row but the last, turn around on the new row
					local originalDir = self.t:getLoc()
					self.t:turnTo((initialD + wDir) % 4)
					while not self.t:suckF() do
						self:checkStorage()
					end
					self.t:mineF()
					while not self.t:suckU() do
						self:checkStorage()
					end
					if self.t:scanU() then
						self.t:digU()
					end
					while not self.t:suckD() do
						self.t:moveB()
						self:checkStorage()
						self.t:moveF()
					end
					if self.t:scanD() then
						self.t:digD()
					end
					self.t:turnTo((originalDir.d + 2) % 4)
					self.t:checkFuel(self.t.homeLoc)
					self:checkStorage()
				end
			end

			-- move up a level
			if self.t:getLoc().y < self.initialLoc.y - self.surfaceBuffer then -- if not at the top
				self.t:moveR()
				self.t:moveR()
				while not self.t:suckU() do
					self:checkStorage()
				end
				self.t:mineU()
				while not self.t:suckU() do
					self:checkStorage()
				end
				self.t:mineU()
				while not self.t:suckU() do
					self:checkStorage()
				end
				self.t:mineU()
				while not self.t:suckU() do
					self:checkStorage()
				end
				if self.t:scanU() then
					self.t:digU()
				end
				wDir = wDir * -1
			else
				break
			end
		end
	end)

	if quarrysuccess then
		print("Mining completed!")
	else
		print("Could not continue mining!")
		print(quarryvalue)
	end

	self:returnToSurface()
	self:dumpItems()
	-- self.t:moveR()
	-- self.t:moveR()
	local endtime = os.clock()
	local mins = math.floor((endtime - starttime) / 60)
	local seconds = math.floor((endtime - starttime) % 60)
	local runtime = mins .. "m " .. seconds .. "s"
	print("Blocks Mined: " .. self.blocksMined)
	print("Runtime: " .. runtime)
	local size = self.quarryLength .. "x" .. self.quarryWidth
	local sizepadded = size
	for i = 1, 7 - #size do
		sizepadded = sizepadded .. " "
	end
	local blockspadded = tostring(self.blocksMined)
	for i = 1, 5 - #tostring(self.blocksMined) do
		blockspadded = blockspadded .. " "
	end
	local h = fs.open("runlog", "a")
	if h ~= nil then
		h.writeLine(sizepadded .. blockspadded .. runtime .. "  d-zone: " .. (self.minY - self.maxY))
		h.close()
	end
end

--## Constructor Method ##--

m.new = function(self, t, l, w, bl)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.t = t
	o:setQuarrySize(l, w)
	o.t:checkForBlacklist(bl)
	o.blacklist = o.t.blacklist
	o.initialLoc = o.t:getLoc()
	return o
end

return m
