-- FastNet2 (Server)
local Server = {}
Server.__index = Server

local Collections = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local FastSpawn = require(script.Parent.FastSpawn)
local Types = require(script.Parent.Types)
local Event = script.Parent.Event

function Server.new(Identifier: string)
	assert(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	assert(not Collections[Identifier], string.format("[FastNet2]: %s already exist", Identifier))
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = nil,
		Connected = false,
		packets = {},
		single = {},
		requests = {},
		flag = {},
		returnRequest = {},
		_ping = nil,
	}, Server)
	return Collections[Identifier]
end

function Server:Connect(callback: Types.callback)
	if self then
		assert(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		self.Connected = true
	end
end

function Server:Listen(callback: Types.callback)
	if self then
		self:Connect(callback)
	end
end

function Server:Wait()
	if self then
		local thread = coroutine.running()
		local clock = os.clock()
		self._ping = function(x)
			self._ping = nil
			task.spawn(thread, x - clock)
		end
		return coroutine.yield()
	end
end

function Server:Once(callback: Types.callback)
	if self and not self.Connected then
		self.func = function(...)
			self:Disconnect()
			task.spawn(callback, ...)
		end
		self.Connected = true
	end
end

function Server:Disconnect()
	if self and self.Connected then
		self.Connected = false
		self.func = nil
	end
end

function Server:Destroy()
	self:Disconnect()
	if self then
		Collections[self.Identifier] = nil
		self = nil
	end
end

function Server:Fire(player: Player, ...: any)
	if not self.single[player.Name] then
		self.single[player.Name] = {}
	end
	table.insert(self.single[player.Name], { ... })
end

function Server:Fires(...: any)
	table.insert(self.packets, { ... })
end

function Server:Pull(expire: number, player: Player, ...: any)
	assert(typeof(expire) == "number", "[FastNet2]: expire argument must be a number.")
	assert(expire > 1, "[FastNet2]: expire argument must be minimum 2.")
	local thread, requestId = coroutine.running(), (#self.flag + 1)
	local session = task.delay(expire, function()
		-- session expire
		-- removing and clear entire requests point
		if self.flag[requestId] then
			table.remove(self.flag, requestId)
		end
		if self.requests[requestId] then
			table.remove(self.flag, requestId)
		end
		coroutine.resume(thread, nil)
	end)
	self.flag[requestId] = function(...)
		task.cancel(session)
		coroutine.resume(thread, ...)
	end
	if not self.requests[player] then
		self.requests[player] = {}
	end
	self.requests[player][requestId] = { ... }
	return coroutine.yield()
end

Event.OnServerEvent:Connect(function(player, packets, secondPackets)
	debug.profilebegin("FastNet2.receive")
	if typeof(packets) == "table" then
		for Identifier, packet in packets do
			if Collections[Identifier] and Collections[Identifier].Connected then
				for _, data in packet do
					FastSpawn(Collections[Identifier].func, player, table.unpack(data))
				end
			end
		end
		table.clear(packets)
	elseif typeof(packets) == "string" then
		if packets == "0" then
			for Identifier, packet in secondPackets do
				if Collections[Identifier] and Collections[Identifier].Connected then
					for i, data in packet do
						if not Collections[Identifier].returnRequest[player.Name] then
							Collections[Identifier].returnRequest[player.Name] = {}
						end
						Collections[Identifier].returnRequest[player.Name][i] = Collections[Identifier].func(player, table.unpack(data))
					end
				end
			end
		elseif packets == "1" then
			for Identifier, packet in secondPackets do
				if Collections[Identifier] then
					for i, data in packet do
						if Collections[Identifier].flag[i] then
							FastSpawn(Collections[Identifier].flag[i], data)
						end
					end
				end
			end
		end
		
		table.clear(secondPackets)
	end
	debug.profileend()
end)

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
				Event:FireClient(Players[player], {[net.Identifier] = table.unpack(packets)})
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

return table.freeze(Server)
