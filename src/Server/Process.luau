local ServerProcess = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Identifiers = require(script.Parent.Identifier)
local FastSpawn = require(script.Parent.Parent.FastSpawn)
local Event = script.Parent.Parent.Event

local Collections = {}

function ServerProcess.reg(Identifier)
	if Identifiers.reg(Identifier) then
		Collections[Identifier] = {
			Identifier = Identifier,
			_ping = nil,
			returnRequest = {},
			requests = {},
			packets = {},
			single = {},
		}
	end
end

function ServerProcess.unreg(Identifier)
	if Identifiers.unreg(Identifier) then
		Collections[Identifier] = nil
	end
end

function ServerProcess.s_insert(Identifier, player, obj)
	if not Collections[Identifier].single[player.Name] then
		Collections[Identifier].single[player.Name] = {}
	end
	table.insert(Collections[Identifier].single[player.Name], obj)
end

function ServerProcess.insert(Identifier, obj)
	table.insert(Collections[Identifier].packets, obj)
end

function ServerProcess.verify(Identifier, player, reqId)
	return Collections[Identifier].requests[player][reqId] ~= nil and true or false
end

function ServerProcess.newReq(Identifier, reqId, player, obj)
	if not Collections[Identifier].requests[player] then
		Collections[Identifier].requests[player] = {}
	end
	Collections[Identifier].requests[player][reqId] = obj
end

function ServerProcess.pushback(Identifier, player, id, obj)
	if not Collections[Identifier].returnRequest[player] then
		Collections[Identifier].returnRequest[player] = {}
	end
	Collections[Identifier].returnRequest[player][id] = obj
	print(Collections[Identifier].returnRequest[player][id], id)
end

function ServerProcess._ping(Identifier)
	local thread = coroutine.running()
	local clock = os.clock()
	Collections[Identifier]._ping = function(x)
		Collections[Identifier]._ping = nil
		task.spawn(thread, x - clock)
	end
	return coroutine.yield()
end

function ServerProcess.__start()
	local _outQueue, outIndex = {}, 0
	RunService.PostSimulation:Connect(function()
		debug.profilebegin("FastNet2.process")
		-- Connections Dataset from Collections
		for Identifier, net in Collections do
			-- Multiple Players to Queue
			if #net.packets > 0 then
				_outQueue[Identifier] = net.packets
				outIndex += 1
				net.packets = {}
			end
			-- Requests to Queue
			for player, requests in net.requests do
				if #requests > 0 then
					Event:FireClient(player, "0", {[net.Identifier] = table.unpack(requests)})
					table.clear(requests)
				end
			end
			-- Single Players to Queue
			for player, packets in net.single do
				if #packets > 0 and Players:FindFirstChild(player) then
					Event:FireClient(Players[player], {[net.Identifier] = packets})
					table.clear(packets)
				end
			end
			-- Return Requests
			for player, data in net.returnRequest do
				if #data > 0 and Players:FindFirstChild(player) then
					Event:FireClient(Players[player], "1", {[net.Identifier] = data})
					table.clear(data)
				end
			end
			-- Ping :Wait()
			if net._ping then
				FastSpawn(net._ping, os.clock())
			end
		end
		-- Sent all data to client (Multiple Players)
		if outIndex > 0 then
			Event:FireAllClients(_outQueue)
			outIndex = 0
			table.clear(_outQueue)
		end
		debug.profileend()
	end)
end

return table.freeze(ServerProcess)