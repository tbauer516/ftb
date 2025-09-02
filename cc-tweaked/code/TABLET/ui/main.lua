local command = require("lib/commands"):new()
local mineCalc = require("lib/minecalc"):new()
local n = require("lib/networking"):new()
local turtlePage = require("ui/turtlezoom")

local m = {}

m.win = nil
m.header = {}
m.body = {}
m.scroll = 0

m.turtleManager = nil

m.redraw = function(self)
	local subPage = nil
	for k, v in pairs(self.body.elem) do
		if v.subPage.win.isVisible() then
			subPage = v.subPage
			break
		end
	end

	if subPage ~= nil then
		subPage.win.redraw()
		subPage:render()
	else
		self.body.selected = {}
		self.header.recordingLoc = nil
		self.win.redraw()
		self:render()
	end
end

m.render = function(self)
	for k, v in pairs(self.header.elem) do
		v:render()
	end
	for k, v in pairs(self.body.elem) do
		v:render()
	end
end

m._createWindow = function(self)
	local w, h = term.getSize()
	self.win = window.create(term.native(), 1, 1, w, h, false)
	self.win.setBackgroundColor(colors.black)
	for i = 1, h do
		self.win.setCursorPos(1, i)
		self.win.write(string.rep(" ", w))
	end

	self.click = function(self, x, y, button)
		self.header:click(x, y, button)
		self.body:click(x, y, button)
	end

	local headerHeight = 4
	self.header.win = window.create(self.win, 1, 1, w, headerHeight, true)
	self.body.win = window.create(self.win, 1, headerHeight + 1, w, h - headerHeight, true)
	self.body.top = self
	self.header.click = function(self, x, y, button)
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
	self.body.getPosByIndex = function(self, index)
		index = index - 1
		local x = ((index % 3) * 8) + (1 + (index % 3))
		local y = (math.floor(index / 3) * 3) + 2
		return { x = x, y = y }
	end
	self.body.getNewPos = function(self)
		local size = 0
		for _, _ in pairs(self.elem) do
			size = size + 1
		end
		return self:getPosByIndex(size + 1)
	end
	self.body.hasCard = function(self, id)
		return self.elem[id] ~= nil
	end
	self.body.add = function(body, id)
		local newPos = body:getNewPos()
		local newCard = self:_createTurtleCard(id, newPos.x, newPos.y)
		body.elem[id] = newCard
		body.top.turtleManager:forEach(function(index, status)
			local adjustedPos = body:getPosByIndex(index)
			local elem = body.elem[status.id]
			if elem ~= nil then
				elem.win.reposition(adjustedPos.x, adjustedPos.y)
			end
		end)
		body.top:render()
	end
	self.body.update = function(self, status)
		self.elem[status.id].subPage:render()
		local subPageVisible = false
		for cardName, card in pairs(self.elem) do
			if card.subPage.win.isVisible() then
				subPageVisible = true
			end
		end
		if not subPageVisible then
			self.elem[status.id]:render()
		end
	end
	self.body.click = function(self, x, y, button)
		local winX, winY = self.win.getPosition()
		local winW, winH = self.win.getSize()
		local offset = winY - 1
		if x < winX or x > winX + winW - 1 or y < winY or y > winY + winH - 1 then
			return
		end
		for k, el in pairs(self.elem) do
			local elX, elY = el.win.getPosition()
			local elW, elH = el.win.getSize()
			if x >= elX and x <= elX + elW - 1 and y - offset >= elY and y - offset <= elY + elH - 1 then
				el:click(x - winX - elX + 2, y - winY - elY + 2, button)
				break
			end
		end
	end
	self.body.selected = {}

	self.header.elem = {}

	for _, elemInit in pairs(self.templates) do
		table.insert(self.header.elem, elemInit(self))
	end

	self.body.elem = {}

	self:render()
end

m.templates = {}

m.templates._createPair = function(self)
	local newWin = window.create(self.header.win, 1, 1, 6, 4, true)
	newWin.setBackgroundColor(colors.yellow)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 2)
	newWin.write(" PAIR ")

	return {
		win = newWin,
		render = function(self) end,
		click = function()
			command:broadcast(command.c.PAIRREQ.gen())
		end,
	}
end

m.templates._createStatusSync = function(self)
	local newWin = window.create(self.header.win, 7, 1, 6, 4, true)
	newWin.setBackgroundColor(colors.cyan)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 2)
	newWin.write("STATUS")

	return {
		win = newWin,
		render = function(self) end,
		click = function()
			command:broadcast(command.c.STATUSREQ.gen())
		end,
	}
end

m.templates._createMoveMulti = function(self)
	local newWin = window.create(self.header.win, 13, 1, 6, 2, true)
	newWin.setBackgroundColor(colors.blue)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 1)
	newWin.write(" MOVE ")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self, _, _, button)
			local newLoc = n:getLoc()
			newLoc.y = newLoc.y - 1
			local assignedTurts = {}
			local locs = {}
			local selectedTurts = self.top.body.selected
			local statusTurts = self.top.turtleManager:getTurtles()
			local turtCount = 0
			for turtID, _ in pairs(selectedTurts) do
				if turtCount == 4 then
					break
				end
				table.insert(locs, { x = newLoc.x, y = newLoc.y, z = newLoc.z })
				table.insert(assignedTurts, statusTurts[turtID])
				self.top.body.selected[turtID] = nil
				turtCount = turtCount + 1
			end
			-- E is +x, S is +z
			for i = 1, #assignedTurts do
				local turt = assignedTurts[i]
				local loc = locs[i]
				if i == 1 then
					loc.z = loc.z - 1
					loc.d = 1
				elseif i == 2 then
					loc.z = loc.z + 1
					loc.d = 3
				elseif i == 3 then
					loc.x = loc.x + 1
					loc.d = 2
				else
					loc.x = loc.x - 1
					loc.d = 0
				end
				command:send(
					assignedTurts[i].id,
					command.c.CRUISETO.gen(loc, math.max(assignedTurts[i].loc.y + 4 + i, loc.y + 4 + i))
				)
			end
			self.top:render()
		end,
	}
end

m.templates._createMineMulti = function(self)
	local newWin = window.create(self.header.win, 13, 3, 6, 2, true)

	return {
		win = newWin,
		top = self,
		render = function(self)
			if self.top.header.recordingLoc == nil then
				self.win.setBackgroundColor(colors.brown)
			else
				self.win.setBackgroundColor(colors.red)
			end
			local elW, elH = self.win.getSize()
			for i = 1, elH do
				self.win.setCursorPos(1, i)
				self.win.write(string.rep(" ", elW))
			end
			self.win.setCursorPos(1, 1)
			self.win.write(" MINE ")
			if self.top.header.recordingLoc ~= nil then
				self.win.setCursorPos(1, elH)
				self.win.write(" rec* ")
			end
		end,
		click = function(self, _, _, button)
			if self.top.header.recordingLoc == nil then
				local newLoc = n:getLoc()
				newLoc.y = newLoc.y - 1
				self.top.header.recordingLoc = newLoc
				self:render()
			elseif button == 2 then
				self.top.header.recordingLoc = nil
				self:render()
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

				local loc1 = self.top.header.recordingLoc
				local loc2 = n:getLoc()
				loc2.y = loc2.y - 1

				local assignedTurts = {}
				local selectedTurts = self.top.body.selected
				local statusTurts = self.top.turtleManager:getTurtles()
				local turtCount = 0
				for turtID, _ in pairs(selectedTurts) do
					turtCount = turtCount + 1
					table.insert(assignedTurts, statusTurts[turtID])
				end

				local dir = mineCalc:getDir({ loc1.x, loc1.y, loc1.z }, { loc2.x, loc2.y, loc2.z })
				local coords = mineCalc:divideClients(
					{ loc1.x, loc1.y, loc1.z },
					{ loc2.x, loc2.y, loc2.z },
					dir,
					#assignedTurts
				)
				for i = 1, #coords do
					local taskList = {
						command.c.SETHOME.gen(),
						command.c.CRUISETO.gen(coords[i], assignedTurts[i].loc.y + 4 + i),
						command.c.MINE.gen(coords[i].l, coords[i].w),
					}
					if blist ~= nil then
						table.insert(taskList, 1, command.c.BLISTRES.gen(blist))
					end
					command:sendMulti(assignedTurts[i].id, taskList)
				end
				self.top.header.recordingLoc = nil
				self.top.body.selected = {}
				self.top:render()
			end
		end,
	}
end

m.templates._createKillMulti = function(self)
	local newWin = window.create(self.header.win, 19, 1, 4, 2, true)
	newWin.setBackgroundColor(colors.magenta)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 1)
	newWin.write("KILL")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			local selectedTurts = self.top.body.selected
			local statusTurts = self.top.turtleManager:getTurtles()
			for turtID, _ in pairs(selectedTurts) do
				command:send(statusTurts[turtID].id, command.c.KILL.gen())
			end
			self.top.body.selected = {}
			self.top:render()
		end,
	}
end

m.templates._createBustMulti = function(self)
	local newWin = window.create(self.header.win, 19, 3, 4, 2, true)
	newWin.setBackgroundColor(colors.pink)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 1)
	newWin.write("BUST")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			local selectedTurts = self.top.body.selected
			local statusTurts = self.top.turtleManager:getTurtles()
			for turtID, _ in pairs(selectedTurts) do
				command:send(statusTurts[turtID].id, command.c.BUST.gen())
			end
			self.top.body.selected = {}
			self.top:render()
		end,
	}
end

m.templates._createSelectAll = function(self)
	local newWin = window.create(self.header.win, 23, 1, 4, 2, true)
	newWin.setBackgroundColor(colors.green)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 1)
	newWin.write(" ALL")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			local statusTurts = self.top.turtleManager:getTurtles()
			for turtID, _ in pairs(statusTurts) do
				self.top.body.selected[turtID] = true
			end
			self.top:render()
		end,
	}
end

m.templates._createSelectNone = function(self)
	local newWin = window.create(self.header.win, 23, 3, 4, 2, true)
	newWin.setBackgroundColor(colors.red)
	local elW, elH = newWin.getSize()
	for i = 1, elH do
		newWin.setCursorPos(1, i)
		newWin.write(string.rep(" ", elW))
	end
	newWin.setCursorPos(1, 1)
	newWin.write("NONE")

	return {
		win = newWin,
		top = self,
		render = function(self) end,
		click = function(self)
			self.top.body.selected = {}
			self.top:render()
		end,
	}
end

m._createTurtleCard = function(self, id, x, y)
	local width = 8

	return {
		win = window.create(self.body.win, x, y, width, 2, true),
		id = id,
		top = self,
		subPage = turtlePage:new(self, id),
		render = function(self)
			local status = self.top.turtleManager:getTurtle(self.id)
			local selectColor = "ee"
			if self.top.body.selected[status.id] == true then
				selectColor = "dd"
			end
			self.win.setBackgroundColor(colors.gray)
			local elW, elH = self.win.getSize()
			for i = 1, elH do
				self.win.setCursorPos(1, i)
				self.win.write(string.rep(" ", elW))
			end
			self.win.setCursorPos(1, 1)
			self.win.blit(
				string.format("%-" .. width .. "s", status.id),
				string.rep("0", width),
				string.rep("7", width - 2) .. selectColor
			)
			self.win.setCursorPos(1, 2)
			self.win.write(status.status .. string.rep(" ", width - string.len(status.status)))
		end,
		click = function(self, x, y)
			local elX, elY = self.win.getPosition()
			local elW, elH = self.win.getSize()
			if x > elW - 2 and y < 2 then
				if self.top.body.selected[self.id] == nil then
					self.top.body.selected[self.id] = true
				else
					self.top.body.selected[self.id] = nil
				end
				self:render()
			else
				self.subPage:display(true)
			end
		end,
	}
end

m.new = function(self, turtleManager)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.turtleManager = turtleManager
	o:_createWindow()

	return o
end

return m
