local m = {}

--## Variables ##--

--## Functions ##--

m.getDir = function(self, p1, p2)
	local p02 = { p2[1] + -1 * p1[1], p2[2], p2[3] + -1 * p1[3] }

	if p02[1] > 0 and p02[3] >= 0 then
		return 0
	elseif p02[1] >= 0 and p02[3] < 0 then
		return 3
	elseif p02[1] <= 0 and p02[3] > 0 then
		return 1
	elseif p02[1] < 0 and p02[3] <= 0 then
		return 2
	else -- covers the 1x1 scenario
		return 0
	end
end

m.divideClients = function(self, p1, p2, dir, numClients)
	local wDir = nil
	local l = nil
	local w = nil
	if dir == 0 then
		wDir = 1
		l = "x"
		w = "z"
	elseif dir == 1 then
		wDir = -1
		l = "z"
		w = "x"
	elseif dir == 2 then
		wDir = -1
		l = "x"
		w = "z"
	else
		wDir = 1
		l = "z"
		w = "x"
	end

	local diffs = { x = math.abs(p2[1] - p1[1]) + 1, z = math.abs(p2[3] - p1[3]) + 1 }

	local offset = math.floor(diffs[w] / numClients)
	local extra = diffs[w] % numClients

	if offset < 1 then -- we have more clients than 1xn rows
		offset = 1
		extra = 0
		numClients = diffs[w]
	end

	local coords = {}
	local lastW = 0
	for i = 1, numClients do
		local coord = { x = p1[1], y = p1[2], z = p1[3], d = dir }

		local additional = lastW + offset
		if extra > 0 then
			additional = additional + 1
			extra = extra - 1
		end
		coord.w = additional - lastW
		coord.l = diffs[l]
		coord[w] = coord[w] + (wDir * lastW)
		lastW = additional

		coords[#coords + 1] = coord
	end

	return coords
end

m.divideClients2D = function(self, p1, p2, dir, numClients)
	local wDir = nil
	local lDir = nil
	local l = nil
	local w = nil
	if dir == 0 then
		wDir = 1
		lDir = 1
		l = "x"
		w = "z"
	elseif dir == 1 then
		wDir = -1
		lDir = 1
		l = "z"
		w = "x"
	elseif dir == 2 then
		wDir = -1
		lDir = -1
		l = "x"
		w = "z"
	else
		wDir = 1
		lDir = -1
		l = "z"
		w = "x"
	end

	local diffs = { x = math.abs(p2[1] - p1[1]) + 1, z = math.abs(p2[3] - p1[3]) + 1 }

	local coords = {}

	if numClients > diffs[w] * diffs[l] then
		numClients = diffs[w] * diffs[l]
	end

	if numClients <= diffs[w] then -- turtles get full length and 1 to many columns
		local wMinWidth = math.floor(diffs[w] / numClients) -- >= 1
		local numWidthExtraWide = diffs[w] % numClients
		for i = 1, numWidthExtraWide do
			local coord = { x = p1[1], y = p1[2], z = p1[3], d = dir }
			coord.w = wMinWidth + 1
			coord.l = diffs[l]
			if coords[#coords] ~= nil and coords[#coords][w] ~= nil then
				coord[w] = coords[#coords][w] + (wDir * coords[#coords].w)
			end

			table.insert(coords, coord)
		end
		for i = 1, numClients - #coords do
			local coord = { x = p1[1], y = p1[2], z = p1[3], d = dir }
			coord.w = wMinWidth
			coord.l = diffs[l]
			if coords[#coords] ~= nil and coords[#coords][w] ~= nil then
				coord[w] = coords[#coords][w] + (wDir * coords[#coords].w)
			end

			table.insert(coords, coord)
		end
	elseif numClients > diffs[w] and numClients <= (diffs[w] * diffs[l]) then -- turtles split length
		local lengthMaxDivide = math.ceil((numClients - diffs[w]) / diffs[w]) + 1 -- factor by which to subdivide
		local numLengthExtraSplit = (numClients - diffs[w]) % diffs[w] -- how many columns require an extra subdivide
		if numLengthExtraSplit == 0 then
			numLengthExtraSplit = diffs[w]
		end
		for i = 1, numLengthExtraSplit do
			local remain = diffs[l] % lengthMaxDivide
			local lastL = 0
			for j = 1, lengthMaxDivide do
				local coord = { x = p1[1], y = p1[2], z = p1[3], d = dir }
				coord.w = 1
				coord.l = math.floor(diffs[l] / lengthMaxDivide)
				if j <= remain then
					coord.l = coord.l + 1
				end
				coord[l] = coord[l] + (lDir * lastL)
				lastL = lastL + coord.l
				coord[w] = coord[w] + (wDir * (i - 1))

				table.insert(coords, coord)
			end
		end
		for i = numLengthExtraSplit + 1, diffs[w] do
			local remain = diffs[l] % (lengthMaxDivide - 1)
			local lastL = 0
			for j = 1, lengthMaxDivide - 1 do
				local coord = { x = p1[1], y = p1[2], z = p1[3], d = dir }
				coord.w = 1
				coord.l = math.floor(diffs[l] / (lengthMaxDivide - 1))
				if j <= remain then
					coord.l = coord.l + 1
				end
				coord[l] = coord[l] + (lDir * lastL)
				lastL = lastL + coord.l
				coord[w] = coord[w] + (wDir * (i - 1))

				table.insert(coords, coord)
			end
		end
	end
	local debug = false
	if debug then
		local message1 = ""
		local message2 = ""
		for _, coord in ipairs(coords) do
			message1 = message1 .. coord.l .. ","
			message2 = message2 .. coord[l] .. ","
		end
		error({ message = message1 .. "\n" .. message2, code = 500 })
	end
	return coords
end

--## Constructor Method ##--

m.new = function(self, n)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

return m
