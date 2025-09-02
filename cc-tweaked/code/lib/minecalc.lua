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

--## Constructor Method ##--

m.new = function(self, n)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

return m
