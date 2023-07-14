--FastNet2 (Client)
local Client = {}
Client.__index = Client
Client.clock = 60

local Collections = {}

local RunService = game:GetService("RunService")
local FastSpawn = require(script.Parent.FastSpawn)
local Types = require(script.Parent.Types)
local Event = script.Parent.Event

function Client.new(Identifier: string)
	assert(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	assert(not Collections[Identifier], string.format("[FastNet2]: %s already exist", Identifier))
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = nil,
		Connected = false,
		packets = {},
		requests = {},
		flag = {},
		_ping = nil,
		returnRequest = {},
	}, Client)
	return Collections[Identifier]
end

function Client:Connect(callback: Types.callback)
	if self then
		assert(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		self.Connected = true
	end
end

function Client:Listen(callback: Types.callback)
	if self then
		self:Connect(callback)
	end
end

function Client:Wait(): number
	if self then
		local thread = coroutine.running()
		local clock = os.clock()
		self._ping = function(x)
			self._ping = 0
			task.spawn(thread, x - clock)
		end
		return coroutine.yield()
	end
end

function Client:Once(callback: Types.callback)
	if self and not self.Connected then
		self.func = function(...)
			self:Disconnect()
			task.spawn(callback, ...)
		end
		self.Connected = true
	end
end

function Client:Disconnect()
	if self and self.Connected then
		self.Connected = false
		self.func = nil
	end
end

function Client:Destroy()
	self:Disconnect()
	if self then
		Collections[self.Identifier] = nil
		self = nil
	end
end

function Client:Fire(...: any)
	table.insert(self.packets, { ... })
end

function Client:Fires()
	warn("[FastNet2]: 'Fires' only can be used on server.")
end

function Client:Pull(expire: number, ...: any)
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
	self.requests[requestId] = { ... }
	return coroutine.yield()
end

Event.OnClientEvent:Connect(function(packets, secondPackets)
	debug.profilebegin("FastNet2.receive")
	if typeof(packets) == "table" then
		for Identifier, packet in packets do
			if Collections[Identifier] and Collections[Identifier].Connected then
				for _, data in packet do
					FastSpawn(Collections[Identifier].func, table.unpack(data))
				end
			end
		end
		table.clear(packets)
	elseif typeof(packets) == "string" then
		if packets == "0" then
			for Identifier, packet in secondPackets do
				if Collections[Identifier] and Collections[Identifier].Connected then
					for i, data in packet do
						Collections[Identifier].returnRequest[i] = Collections[Identifier].func(data)
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

local clock, _outQueue, outIndex = os.clock(), {}, 0
local inRequestQueue, inRequestIndex = {}, 0
local throwRequest, throwIndex = {}, 0
RunService.PostSimulation:Connect(function()
	if (os.clock() - clock) >= 1/Client.clock - 0.00015 then
		clock = os.clock()
		debug.profilebegin("FastNet2.process")
		
		for Identifier, net in Collections do
			-- Packet to Queue
			if #net.packets > 0 then
				_outQueue[Identifier] = net.packets
				outIndex += 1
				net.packets = {}
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
			Event:FireServer(_outQueue)
			outIndex = 0
			table.clear(_outQueue)
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
	end
end)

return table.freeze(Client)
