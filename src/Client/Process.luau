local ClientProcess = {}
ClientProcess.rateLimit = 250 -- max rate limit (default: 250)
ClientProcess.maxFreeze = 1 -- max duration freezing reaching rate limit (default: 1)

local RunService = game:GetService("RunService")
local Identifiers = require(script.Parent.Identifier)
local FastSpawn = require(script.Parent.Parent.FastSpawn)
local Event = script.Parent.Parent.Event

local Collections = {}
local Outgoing = {}

function ClientProcess.reg(Identifier)
	if Identifiers.reg(Identifier) then
		Collections[Identifier] = {
			OutgoingOrder = 0,
			_ping = nil,
			returnRequest = {},
			requests = {},
			_rate = os.clock(),
			_pre = {},
			_pre_p = {},
			_pre_f = nil,
		}
		Outgoing[Identifier] = {}
	end
end

function ClientProcess.unreg(Identifier)
	if Identifiers.unreg(Identifier) then
		Collections[Identifier] = nil
		Outgoing[Identifier] = nil
	end
end

function ClientProcess.insert(Identifier, obj)
	Collections[Identifier].OutgoingOrder += 1
	Outgoing[Identifier][Collections[Identifier].OutgoingOrder] = obj
end

function ClientProcess.verify(Identifier, reqId)
	return Collections[Identifier].requests[reqId] ~= nil and true or false
end

function ClientProcess.newReq(Identifier, reqId, obj)
	Collections[Identifier].requests[reqId] = obj
end

function ClientProcess.pushback(Identifier, id, obj)
	Collections[Identifier].returnRequest[id] = obj
end

function ClientProcess._ping(Identifier)
	local thread = coroutine.running()
	local clock = os.clock()
	Collections[Identifier]._ping = function(x)
		Collections[Identifier]._ping = nil
		task.spawn(thread, x - clock)
	end
	return coroutine.yield()
end

function ClientProcess._pre(Identifier, pre)
	Collections[Identifier]._pre[#Collections[Identifier]._pre + 1] = pre
end

function ClientProcess._pre_p(Identifier, pre)
	Collections[Identifier]._pre_p[#Collections[Identifier]._pre_p + 1] = pre
end

function ClientProcess.reg_pre_f(Identifier, f)
	Collections[Identifier]._pre_f = f
end

function ClientProcess.unreg_pre_f(Identifier)
	Collections[Identifier]._pre_f = nil
end

function ClientProcess.__start()
	local outQueue, outIndex = {}, 0
	local inRequestQueue, inRequestIndex = {}, 0
	local throwRequest, throwIndex = {}, 0
	
	RunService.PostSimulation:Connect(function()
		debug.profilebegin("FastNet2.sent")
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
		
		debug.profilebegin("FastNet2.process")
		-- Process
		for Identifier, net in Collections do
			if #net._pre > 0 and net._pre_f then
				for _, data in net._pre do
					for _, x in data do
						FastSpawn(net._pre_f, table.unpack(x))
					end
				end
				table.clear(net._pre)
				for _, data in net._pre_p do
					for i, x in data do
						ClientProcess.pushback(Identifier, i, net._pre_f(x))
					end
				end
				table.clear(net._pre_p)
			end
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
		debug.profileend()
	end)
end

return table.freeze(ClientProcess)