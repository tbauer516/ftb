local m = {}

m._options = {}
m._scrollpos = 1
m._selectedRow = 1
m._selectedCol = 1
m.type = "interact"
m.rows = {}

--## Private Functions

local stringsplit = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

m._wrapOptions = function(self, val, min, max)
	if min <= max and val < min then
		val = max
	elseif min <= max and val > max then
		val = min
	end
	return val
end

--## Public Functions

--dir: -1 is up, 1 is down
m.scroll = function(self, win, dir)
	local w, h = win.getSize()
	if h >= #self.rows then
		return
	elseif self._selectedRow < self._scrollpos then -- up
		self._scrollpos = self._selectedRow
	elseif self._selectedRow > self._scrollpos + h - 1 and self._scrollpos <= (#self.rows - h) then -- down
		self._scrollpos = self._selectedRow - h + 1
	end
end

m.selectRow = function(self, dir)
	local oldSelected = self._selectedRow
	if dir == -1 and self._selectedRow > 1 then -- up
		self._selectedRow = self._selectedRow - 1
	elseif dir == 1 and self._selectedRow < #self.rows then -- down
		self._selectedRow = self._selectedRow + 1
	end

	if self._selectedCol == 2 and self._options[self.rows[self._selectedRow].type] ~= "Filter" then
		self._selectedRow = oldSelected
	end
end

m.selectCol = function(self, dir)
	if self._options[self.rows[self._selectedRow].type] ~= "Filter" then
		self.rows[self._selectedRow].pair = 0
		return
	end
	if dir == -1 and self._selectedCol > 1 then -- up
		self._selectedCol = self._selectedCol - 1
	elseif dir == 1 and self._selectedCol < 2 then -- down
		self._selectedCol = self._selectedCol + 1
	end
end

m.changeOption = function(self, dir)
	if self._selectedCol == 1 then
		self.rows[self._selectedRow].type =
			self:_wrapOptions(self.rows[self._selectedRow].type + dir, 1, #self._options)
		if self._options[self.rows[self._selectedRow].type] ~= "Filter" then
			self.rows[self._selectedRow].pair = 0
		end
	elseif self._selectedCol == 2 then
		self.rows[self._selectedRow].pair = self:_wrapOptions(self.rows[self._selectedRow].pair + dir, 0, #self.rows)
	end
end

m.validate = function(self, results)
	--find all filters and make sure they match up to an output
	for _, row in ipairs(results.Filter) do
		if self._options[self.rows[row.pair].type] ~= "Output" then
			return false
		end
	end
	-- track the outputs and filter out ones that are filtered
	if #results.Output - #results.Filter ~= 1 then
		return false
	end
	-- check if there's at least 1 input
	if #results.Input < 1 then
		return false
	end
	return true
end

m.submit = function(self)
	local results = {}
	for _, category in ipairs(self._options) do
		results[category] = {}
	end
	for index, row in ipairs(self.rows) do
		local subTable = self._options[row.type]
		local chest = { id = index, name = row.name }
		if row.pair ~= 0 then
			chest.pair = row.pair
			chest.pairName = self.rows[row.pair].name
		end
		table.insert(results[subTable], chest)
	end
	for _, filter in ipairs(results["Filter"]) do
		for _, output in ipairs(results["Output"]) do
			if filter.pairName == output.name then
				output.hasFilter = true
			end
		end
	end

	local debugmode = false
	if debugmode then
		for subTable, tableValues in pairs(results) do
			print(subTable .. ":")
			for _, chest in ipairs(tableValues) do
				print("id: " .. chest.id .. ", chest:" .. chest.name .. ", pair: " .. (chest.pair or ""))
			end
		end
	end
	return results
end

m.display = function(self, win)
	win.clear()
	local w, h = win.getSize()
	win.setCursorPos(1, 1)

	local max = math.min(h + self._scrollpos - 1, #self.rows)
	local lineIndex = 1
	local col2W = 1
	local col3W = 1
	for i = self._scrollpos, max do
		col2W = math.max(col2W, #self._options[self.rows[i].type])
		col3W = math.max(col3W, #tostring(self.rows[i].pair))
	end
	for i = self._scrollpos, max do
		win.setCursorPos(1, lineIndex)
		local col1 = nil
		if i < 10 then
			col1 = " " .. i
		else
			col1 = "" .. i
		end
		local col2 = self._options[self.rows[i].type]
		for i = 1, math.floor((col2W - #col2) / 2) do
			col2 = " " .. col2
		end
		for i = 1, col2W - #col2 do
			col2 = col2 .. " "
		end
		local col3 = tostring(self.rows[i].pair)
		if self.rows[i].pair == 0 then
			col3 = " "
		end
		for i = 1, col3W - #col3 do
			col3 = " " .. col3
		end

		if self._selectedRow == i and self._selectedCol == 1 then
			col2 = "[" .. col2 .. "]"
			col3 = " " .. col3 .. " "
		elseif self._selectedRow == i and self._selectedCol == 2 then
			col2 = " " .. col2 .. " "
			col3 = "[" .. col3 .. "]"
		else
			col2 = " " .. col2 .. " "
			col3 = " " .. col3 .. " "
		end
		local chestName = stringsplit(self.rows[i].name, ":")
		win.write(col1 .. " | " .. col2 .. " | " .. col3 .. " | " .. chestName[#chestName])
		lineIndex = lineIndex + 1
	end
end

m.run = function(self, win)
	self:display(win)
	while true do
		local event = { os.pullEvent() }
		if event[1] == "key" then
			if event[2] == keys.down then
				self:changeOption(-1)
			elseif event[2] == keys.up then
				self:changeOption(1)
			elseif event[2] == keys.w then
				self:selectRow(-1)
			elseif event[2] == keys.s then
				self:selectRow(1)
			elseif event[2] == keys.a then
				self:selectCol(-1)
			elseif event[2] == keys.d then
				self:selectCol(1)
			elseif event[2] == keys.enter then
				local results = self:submit()
				if self:validate(results) then
					return results
				else
					term.clear()
					term.setCursorPos(1, 1)
					print("Did not pass validation")
					sleep(2)
				end
			end
		end
		self:display(win)
	end
end

--## Constructor ##--

--Common
m.new = function(_, lines, inputs, outputs, filters)
	local o = {}
	setmetatable(o, { __index = m })
	if lines == nil then
		lines = {}
	end
	o._options = { "Input", "Output", "Filter" }

	local removed = {}
	for i, subType in ipairs({ inputs, outputs, filters }) do
		for _, chest in ipairs(subType) do
			local index = chest.id
			chest.type = i
			if chest.pair == nil then
				chest.pair = 0
			end
			local existing = false
			for j, name in ipairs(lines) do
				if chest.name == name then
					existing = true
					o.rows[index] = chest
					table.remove(lines, j)
					break
				end
			end
			if not existing then
				table.insert(removed, index)
			end
		end
	end

	if #removed > 0 then
		for i = #removed, 1, -1 do
			local toRemove = removed[i]
			table.remove(o.rows, toRemove)
		end
		for _, chest in ipairs(o.rows) do
			chest.pair = 0
		end
	end

	for _, name in ipairs(lines) do
		local newChest = {}
		newChest.pair = 0
		newChest.type = 1
		newChest.name = name
		table.insert(o.rows, newChest)
	end

	return o
end

return m
