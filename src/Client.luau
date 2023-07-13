--FastNet2 (Client)
local Client = {}
Client.__index = Client
Client.clock = 60

local Collections = {}

local RunService = game:GetService("RunService")
local FastSpawn = require(script.Parent.FastSpawn)
local Event = script.Parent.Event

export type callback = (...any) -> ()

function Client.new(Identifier: string)
	assert(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	assert(not Collections[Identifier], string.format("[FastNet2]: %s already exist", Identifier))
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = nil,
		Connected = false,
		packets = {},
		_ping = nil,
	}, Client)
	return Collections[Identifier]
end

function Client:Connect(callback: callback)
	if self then
		assert(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		self.Connected = true
	end
end

function Client:Wait()
	if self then
		local thread = coroutine.running()
		local clock = os.clock()
		self._ping = function(x)
			task.spawn(thread, x - clock)
			self._ping = nil
		end
		return coroutine.yield()
	end
end

function Client:Once(callback: callback)
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
	warn("[FastNet2]: Attempt to index nil with ‘Fires'")
end

Event.OnClientEvent:Connect(function(packets)
	debug.profilebegin("FastNet2.receive")
	for Identifier, packet in packets do
		if Collections[Identifier] and Collections[Identifier].Connected then
			for _, data in packet do
				FastSpawn(Collections[Identifier].func, data)
			end
		end
	end
	table.clear(packets)
	debug.profileend()
end)

local clock = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - clock) >= 1/Client.clock - 0.00015 then
		clock = os.clock()
		debug.profilebegin("FastNet2.process")

		local _outQueue, outIndex = {}, 0
		for Identifier, net in Collections do
			if net.Connected and #net.packets > 0 then
				_outQueue[Identifier] = net.packets
				outIndex += 1
				net.packets = {}
			end
			if net._ping then
				FastSpawn(net._ping, os.clock())
			end
		end
		if outIndex > 0 then
			Event:FireServer(_outQueue)
			outIndex = nil
			table.clear(_outQueue)
		end

		debug.profileend()
	end
end)

return table.freeze(Client)
