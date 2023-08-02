--!strict
local ClientProcess = {}
ClientProcess.rateLimit = 250 -- max rate limit (default: 250)
ClientProcess.maxFreeze = 1 -- max duration freezing reaching rate limit (default: 1)

local RunService = game:GetService("RunService")
local Identifiers = require(script.Parent.Identifier)
local FastSpawn = require(script.Parent.Parent.FastSpawn)
local Event = script.Parent.Parent.Event

local Collections = {}
local Outgoing = {}

function ClientProcess.reg(Identifier: string)
	if Identifiers.reg(Identifier) then
		Collections[Identifier] = {
			OutgoingOrder = 0,
			_ping = nil,
			returnRequest = {},
			requests = {},
			_rate = os.clock(),
		} :: any
		Outgoing[Identifier] = {}
	end
end

function ClientProcess.unreg(Identifier: string)
	if Identifiers.unreg(Identifier) then
		table.clear(Outgoing[Identifier])
	end
end

function ClientProcess.insert(Identifier: string, obj)
	Collections[Identifier].OutgoingOrder += 1
	Outgoing[Identifier][Collections[Identifier].OutgoingOrder] = obj
end

function ClientProcess.verify(Identifier: string, reqId: number): boolean
	return Collections[Identifier].requests[reqId] ~= nil and true or false
end

function ClientProcess.newReq(Identifier: string, reqId: number, obj)
	Collections[Identifier].requests[reqId] = obj
end

function ClientProcess.pushback(Identifier: string, id: number, obj)
	Collections[Identifier].returnRequest[id] = obj
end

function ClientProcess._ping(Identifier: string): number
	local thread = coroutine.running()
	local clock = os.clock()
	Collections[Identifier]._ping = function(x: number)
		Collections[Identifier]._ping = nil
		task.spawn(thread, x - clock)
	end
	return coroutine.yield()
end

function ClientProcess.__start()
	local outQueue, outIndex = {}, 0
	local inRequestQueue, inRequestIndex = {}, 0
	local throwRequest, throwIndex = {}, 0
	
	RunService.PostSimulation:Connect(function()
		debug.profilebegin("FastNet2.process")
		for Identifier: string, net in Collections do
			-- Packet to Queue
			if #Outgoing[Identifier] > 0 then
				if #Outgoing[Identifier] > ClientProcess.rateLimit then
					if not outQueue[Identifier] then
						outQueue[Identifier] = {}
					end
					if (os.clock() - net._rate) >= ClientProcess.maxFreeze then
						net._rate = os.clock()
						for i=1,ClientProcess.rateLimit do
							outQueue[Identifier][i] = Outgoing[Identifier][i]
							net.OutgoingOrder -= 1
							table.remove(Outgoing[Identifier], i)
						end
					end
				else
					outQueue[Identifier] = Outgoing[Identifier]
					net.OutgoingOrder = 0
					Outgoing[Identifier] = {}
				end
				if #outQueue[Identifier] > 0 then
					outIndex += 1
				end
			end
			-- Request to Queue
			if #net.requests > 0 then
				inRequestQueue[Identifier] = net.requests
				inRequestIndex += 1
				net.requests = {}
			end
			-- Return Requests
			if #net.returnRequest > 0 then
				throwRequest[Identifier] = net.returnRequest
				throwIndex += 1
				net.returnRequest = {}
			end
			-- Ping :Wait()
			if net._ping then
				FastSpawn(net._ping, os.clock())
			end
		end
		-- Sent queues to server
		if outIndex > 0 then
			Event:FireServer(outQueue)
			outIndex = 0
			table.clear(outQueue)
		end
		if inRequestIndex > 0 then
			Event:FireServer("0", inRequestQueue)
			inRequestIndex = 0
			table.clear(inRequestQueue)
		end
		if throwIndex > 0 then
			Event:FireServer("1", throwRequest)
			throwIndex = 0
			table.clear(throwRequest)
		end
		debug.profileend()
	end)
end

return table.freeze(ClientProcess)