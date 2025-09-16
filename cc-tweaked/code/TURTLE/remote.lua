local n = require("lib/networking"):new()
local t = require("lib/t"):new(n)
local quarry = require("lib/quarry")
local command = require("lib/commands"):new(t)

local dependencies = {
	"blacklist/",
	"lib/",
	"remote.lua",
}

--## Variables ## --

local args = { ... }

--## UI-ish functions ##--

local displayText = function()
	term.clear()
	term.setCursorPos(1, 1)
	local status = t:getStatus()
	print("ID: " .. status.id)
	print()
	print("Task: " .. status.status)
	print("Fuel: " .. status.fuel)
	print(t:getLocString(t:getLoc()))
	print()
end

local sendStatusUpdate = function()
	if n.serverID ~= nil then
		command:send(n.serverID, command.c.STATUSRES.gen(t:getStatus()))
	end
end

--## Translate Network Instructions ##--

local taskHandler = function()
	while true do
		t:setStatus("IDLE")
		sendStatusUpdate()
		displayText()
		os.pullEvent("turtle_task")
		while #command.taskQueue > 0 do
			local message = table.remove(command.taskQueue, 1)
			local senderID = message[1]
			local params = message[2]
			local proto = message[3]
			local task = params[1]
			local taskDetails = params[2]

			if command.c[task] ~= nil then
				t:setStatus(task)
				sendStatusUpdate()
				displayText()
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
				if proto ~= command.protocol and proto ~= command.protocolMulti then
					return
				end
				if n.serverID ~= nil and n.serverID ~= senderID then
					return
				end

				local tasks = params
				if proto == command.protocol then
					tasks = { params }
				end

				for _, task in ipairs(tasks) do
					table.insert(task[2], senderID)
					if command.c[task[1]] ~= nil and command.c[task[1]].priority == 1 then
						command.c[task[1]].han(command, unpack(task[2]))
					else
						table.insert(command.taskQueue, { senderID, task, proto })
						os.queueEvent("turtle_task")
					end
				end
			end,
			["key"] = function(keyID, heldDown)
				if keyID == keys.delete then
					error({ message = "physical KILLswitch pressed", code = 500 })
				end
			end,
		}
		if look[event[1]] ~= nil then
			look[event[1]](event[2], event[3], event[4])
		end
	end
end

--## Main Runtime ##--

if args[1] == nil then
	local timerID = os.startTimer(math.random(5, 20))
	while true do
		local event = { os.pullEvent("timer") }
		if event[2] == timerID then
			break
		end
	end
end

os.setComputerLabel("" .. os.computerID())
if not fs.exists("startup.lua") then
	local h = fs.open("startup.lua", "w")
	if h ~= nil then
		h.write('shell.run("remote")')
		h.close()
	end
end

if not n:checkModem() then
	error("Please run on a wireless mining turtle")
end
n:checkServerID()
t:setLocFromGPS()
t:loadHomeLoc()
if n.serverID ~= nil then
	command:send(n.serverID, command.c.CHECKRES.gen(t:getStatus()))
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
