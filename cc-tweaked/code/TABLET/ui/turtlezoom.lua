local command = require("lib/commands"):new()
local n = require("lib/networking"):new()
local mineCalc = require("lib/minecalc"):new()

local m = {}

local statusTemplate = {
	id = "num",
	loc = "turtle_loc",
	fuel = "num",
	inventory = "table",
	inventoryTotal = "num",
	status = "string",
}

m.update = function(self, status)
	self.status = status
end

m.display = function(self, visible)
	self.win.setVisible(visible)
	self:render()
end

m.render = function(self)
	for elementName, element in pairs(self.elem) do
		element:render()
	end
end

m._createWindow = function(self)
	self.elem = {}
	self.controlling = false
	self.recordingLoc = nil

	local w, h = term.getSize()
	self.win = window.create(term.native(), 1, 1, w, h, false)
	self.win.setBackgroundColor(colors.black)
	for i = 1, h do
		self.win.setCursorPos(1, i)
		self.win.write(string.rep(" ", w))
	end

	self.getNewPos = function(self)
		local size = 0
		for _, _ in pairs(self.elem) do
			size = size + 1
		end
		local x = ((size % 3) * 8) + (1 + (size % 3))
		local y = (math.floor(size / 3) * 3) + 2
		return { x = x, y = y }
	end
	self.hasCard = function(self, id)
		return self.elem[id] ~= nil
	end
	self.add = function(self, status)
		local newPos = self:getNewPos()
		local newCard = m:_createTurtleCard(status, newPos.x, newPos.y)
		self.elem[status.id] = newCard
		-- newCard:render()
	end
	self.update = function(self, status)
		for elemName, elem in pairs(self.elem) do
			elem:render()
		end
	end
	self.click = function(self, x, y, button)
		local winX, winY = self.win.getPosition()
		local winW, winH = self.win.getSize()
		if x < winX or x > winX + winW - 1 or y < winY or y > winY + winH - 1 then
			return
		end
		for k, el in pairs(self.elem) do
			local elX, elY = el.win.getPosition()
			local elW, elH = el.win.getSize()
			if x >= elX and x <= elX + elW - 1 and y >= elY and y <= elY + elH - 1 then
				el:click(x, y, button)
				break
			end
		end
	end

	for _, elemInit in pairs(self.templates) do
		table.insert(self.elem, elemInit(self))
	end

	table.insert(self.elem, self:placeholder(7, 17, 6, 3))

	-- self:render()
end

m.templates = {}

m.templates._createExit = function(self)
	local newWin = window.create(self.win, 1, 1, 3, 1, true)
	newWin.setBackgroundColor(colors.gray)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	newWin.write(" < ")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			self.top.controlling = false
			self.top.recordingLoc = nil
			self.top:render()
			self.top:display(false)
			self.top.main:redraw()
		end,
	}
end

m.templates._createRefresh = function(self)
	local newWin = window.create(self.win, 4, 1, 3, 1, true)
	newWin.setBackgroundColor(colors.cyan)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	newWin.write(" @ ")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			self.top.controlling = false
			self.top.recordingLoc = nil
			command:send(self.top.id, command.c.STATUSREQ.gen())
		end,
	}
end

m.templates._createAbort = function(self)
	local newWin = window.create(self.win, 7, 1, 3, 1, true)
	newWin.setBackgroundColor(colors.magenta)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	newWin.write(" ! ")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.KILL.gen())
		end,
	}
end

m.templates._createBust = function(self)
	local newWin = window.create(self.win, 10, 1, 3, 1, true)
	newWin.setBackgroundColor(colors.pink)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	newWin.write(" ? ")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.BUST.gen())
		end,
	}
end

m.templates._createControl = function(self)
	return {
		win = window.create(self.win, 13, 1, 14, 1, true),
		top = self,
		render = function(self)
			if not self.top.controlling then
				self.win.setBackgroundColor(colors.green)
			else
				self.win.setBackgroundColor(colors.red)
			end
			local elW, elH = self.win.getSize()
			self.win.setCursorPos(1, 1)
			if not self.top.controlling then
				self.win.write(" control: no  ")
			else
				self.win.write(" control: yes ")
			end
		end,
		click = function(self)
			self.top.controlling = not self.top.controlling
			self:render()
		end,
	}
end

m.templates._createTitle = function(self)
	local newWin = window.create(self.win, 1, 3, 10, 2, true)
	newWin.setBackgroundColor(colors.lightGray)
	local elW, elH = newWin.getSize()

	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end

	return {
		win = newWin,
		top = self,
		render = function(self)
			local status = self.top.main.turtleManager:getTurtle(self.top.id)

			self.win.setBackgroundColor(colors.lightGray)
			self.win.setCursorPos(1, 1)
			self.win.write("ID: " .. status.id)
			self.win.setCursorPos(1, 2)
			self.win.write(string.format("%-" .. elW .. "s", status.status))
		end,
		click = function(self) end,
	}
end

m.templates._createLocation = function(self)
	local newWin = window.create(self.win, 11, 3, 16, 2, true)
	newWin.setBackgroundColor(colors.gray)
	local elW, elH = newWin.getSize()

	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end

	return {
		win = newWin,
		top = self,
		render = function(self)
			local status = self.top.main.turtleManager:getTurtle(self.top.id)

			self.win.setBackgroundColor(colors.gray)
			self.win.setCursorPos(1, 1)
			self.win.write(" Y:" .. status.loc.y)
			self.win.setCursorPos(9, 1)
			self.win.write(" D:" .. status.loc.dString)
			self.win.setCursorPos(1, 2)
			self.win.write(" X:" .. status.loc.x)
			self.win.setCursorPos(9, 2)
			self.win.write(" Z:" .. status.loc.z)
		end,
		click = function(self) end,
	}
end

m.templates._createFuel = function(self)
	local newWin = window.create(self.win, 14, 6, 13, 2, true)
	newWin.setBackgroundColor(colors.gray)
	local elW, elH = newWin.getSize()

	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end

	return {
		win = newWin,
		top = self,
		render = function(self)
			local status = self.top.main.turtleManager:getTurtle(self.top.id)

			self.win.setBackgroundColor(colors.gray)
			self.win.setCursorPos(1, 1)
			self.win.write(" Fuel: " .. status.fuel)
			self.win.setCursorPos(1, 2)
			self.win.write(" Inv: " .. status.inventoryTotal)
		end,
		click = function(self) end,
	}
end

m.templates._createInventory = function(self)
	local newWin = window.create(self.win, 15, 13, 11, 7, true)
	local squareW, squareH = 2, 1
	newWin.setBackgroundColor(colors.black)
	local elW, elH = newWin.getSize()

	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end

	newWin.setBackgroundColor(colors.gray)
	for row = 1, 4 do
		for col = 1, 4 do
			for cellRow = 1, squareH do
				newWin.setCursorPos((col * (squareW + 1)) - squareW, (row * (squareH + 1)) - squareH + cellRow - 1)
				newWin.write(string.rep(" ", squareW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self)
			local status = self.top.main.turtleManager:getTurtle(self.top.id)

			self.win.setBackgroundColor(colors.gray)
			for index = 1, 16 do
				local item = status.inventory[index]
				local count = ""
				if item ~= nil then
					count = item.count
				end
				local row = math.floor((index - 1) / 4) + 1
				local col = ((index - 1) % 4) + 1
				self.win.setCursorPos(
					(col * (squareW + 1)) - squareW,
					(row * (squareH + 1)) - squareH + math.ceil(squareH / 2) - 1
				)
				local leftPad = squareW - math.ceil((squareW - 2) / 2)
				local rightPad = squareW
				self.win.write(string.format("%-" .. rightPad .. "s", string.format("%" .. leftPad .. "s", count)))
			end
		end,
		click = function(self) end,
	}
end

m.templates._createResetLoc = function(self)
	local newWin = window.create(self.win, 1, 17, 5, 3, true)
	newWin.setBackgroundColor(colors.green)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write("RESET")
			elseif row == 3 then
				newWin.write(" LOC ")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.RESETLOC.gen())
		end,
	}
end

m.templates._createMoveHome = function(self)
	local newWin = window.create(self.win, 1, 9, 5, 3, true)
	newWin.setBackgroundColor(colors.blue)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write(" MOVE")
			elseif row == 3 then
				newWin.write(" HOME")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.MOVEHOME.gen())
		end,
	}
end

m.templates._createMoveHere = function(self)
	local newWin = window.create(self.win, 7, 9, 6, 3, true)
	newWin.setBackgroundColor(colors.blue)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write(" MOVE ")
			elseif row == 3 then
				newWin.write(" HERE ")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			local newLoc = n:getLoc()
			newLoc.y = newLoc.y - 1
			local status = self.top.main.turtleManager:getTurtle(self.top.id)
			newLoc.d = status.loc.d
			local cruiseHeight = math.max(newLoc.y, status.loc.y)
			command:send(self.top.id, command.c.CRUISETO.gen(newLoc, cruiseHeight + 4))
		end,
	}
end

m.templates._createSetHome = function(self)
	local newWin = window.create(self.win, 14, 9, 6, 3, true)
	newWin.setBackgroundColor(colors.orange)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write("  SET ")
			elseif row == 3 then
				newWin.write(" HOME ")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.SETHOME.gen())
		end,
	}
end

m.templates._createMine = function(self)
	local newWin = window.create(self.win, 21, 9, 6, 3, true)

	return {
		win = newWin,
		top = self,
		render = function(self)
			if self.top.recordingLoc == nil then
				self.win.setBackgroundColor(colors.brown)
			else
				self.win.setBackgroundColor(colors.red)
			end
			local elW, elH = self.win.getSize()
			self.win.setCursorPos(1, 1)
			for col = 1, elW do
				for row = 1, elH do
					self.win.setCursorPos(1, row)
					if row == 2 then
						self.win.write(" MINE ")
					else
						self.win.write(string.rep(" ", elW))
					end
				end
			end
			if self.top.recordingLoc ~= nil then
				self.win.setCursorPos(1, 3)
				self.win.write(" rec* ")
			end
		end,
		click = function(self, _, _, button)
			if self.top.recordingLoc == nil then
				local newLoc = n:getLoc()
				newLoc.y = newLoc.y - 1
				self.top.recordingLoc = newLoc
			elseif button == 2 then
				self.top.recordingLoc = nil
			else
				local blist = nil
				local h = fs.open("blacklist/default.blist", "r")
				if h ~= nil then
					local text = h.readAll()
					if type(text) == "string" then
						local unserialized = textutils.unserialize(text)
						blist = unserialized
					end
					h.close()
				end
				local status = self.top.main.turtleManager:getTurtle(self.top.id)
				local loc1 = self.top.recordingLoc
				local loc2 = n:getLoc()
				loc2.y = loc2.y - 1

				local dir = mineCalc:getDir({ loc1.x, loc1.y, loc1.z }, { loc2.x, loc2.y, loc2.z })
				local coords = mineCalc:divideClients({ loc1.x, loc1.y, loc1.z }, { loc2.x, loc2.y, loc2.z }, dir, 1)
				local taskList = {
					command.c.CHECKFUEL.gen(500),
					command.c.SETHOME.gen(),
					command.c.CRUISETO.gen(coords[1], status.loc.y + 4),
					command.c.MINE.gen(coords[1].l, coords[1].w),
				}
				if blist ~= nil then
					table.insert(taskList, 1, command.c.BLISTRES.gen(blist))
				end
				command:sendMulti(self.top.id, taskList)
				self.top.recordingLoc = nil
			end
			self:render()
		end,
	}
end

m.templates._createBListGet = function(self)
	local newWin = window.create(self.win, 1, 13, 5, 3, true)
	newWin.setBackgroundColor(colors.blue)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write("BLIST")
			elseif row == 3 then
				newWin.write(" GET ")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			command:send(self.top.id, command.c.BLISTREQ.gen())
		end,
	}
end

m.templates._createBListSend = function(self)
	local newWin = window.create(self.win, 7, 13, 6, 3, true)
	newWin.setBackgroundColor(colors.blue)
	local elW, elH = newWin.getSize()
	newWin.setCursorPos(1, 1)
	for col = 1, elW do
		for row = 1, elH do
			newWin.setCursorPos(1, row)
			if row == 2 then
				newWin.write(" BLIST")
			elseif row == 3 then
				newWin.write(" SEND ")
			else
				newWin.write(string.rep(" ", elW))
			end
		end
	end

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			local h = fs.open("blacklist/default.blist", "r")
			if h ~= nil then
				local text = h.readAll()
				if type(text) == "string" then
					local unserialized = textutils.unserialize(text)
					command:send(self.top.id, command.c.BLISTRES.gen(unserialized))
				end
				h.close()
			end
		end,
	}
end

m.placeholder = function(self, x, y, w, h)
	local newWin = window.create(self.win, x, y, w, h, true)

	return {
		win = newWin,
		top = self,
		render = function(self)
			self.win.setBackgroundColor(colors.gray)
			local elW, elH = self.win.getSize()
			self.win.setCursorPos(1, 1)
			for col = 1, elW do
				for row = 1, elH do
					self.win.setCursorPos(1, row)
					self.win.write(string.rep(" ", elW))
				end
			end
		end,
		click = function(self) end,
	}
end

m.new = function(self, top, id)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.main = top
	o.id = id
	o:_createWindow()

	return o
end

return m
