-- FastNet2 (Server)
local Server = {}
Server.__index = Server

local Collections = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local FastSpawn = require(script.Parent.FastSpawn)
local Event = script.Parent.Event

export type callback = (...any) -> ()

function Server.new(Identifier: string)
	assert(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	assert(not Collections[Identifier], string.format("[FastNet2]: %s already exist", Identifier))
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = nil,
		Connected = false,
		packets = {},
		single = {},
		_ping = nil,
	}, Server)
	return Collections[Identifier]
end

function Server:Connect(callback: callback)
	if self then
		assert(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		self.Connected = true
	end
end

function Server:Wait()
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

function Server:Once(callback: callback)
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

Event.OnServerEvent:Connect(function(player, packets)
	debug.profilebegin("FastNet2.receive")
	for Identifier, packet in packets do
		if Collections[Identifier] and Collections[Identifier].Connected then
			for _, data in packet do
				FastSpawn(Collections[Identifier].func, player, table.unpack(data))
			end
		end
	end
	table.clear(packets)
	debug.profileend()
end)

RunService.PostSimulation:Connect(function()
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
		Event:FireAllClients(_outQueue)
		outIndex = nil
		table.clear(_outQueue)
	end
	for Identifier, net in Collections do
		if net.Connected then
			for player, packets in net.single do
				if #packets > 0 and Players:FindFirstChild(player) then
					Event:FireClient(Players[player], table.unpack(packets))
					packets = {}
				end
			end
		end
	end

	debug.profileend()
end)

return table.freeze(Server)
