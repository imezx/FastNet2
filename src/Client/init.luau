--FastNet2 (Client)
local Client = {}
Client.__index = Client

local RunService = game:GetService("RunService")

local Process = require(script.Process)
local Identifiers = require(script.Identifier)
local FastSpawn = require(script.Parent.FastSpawn)
local Types = require(script.Parent.Types)
local Event = script.Parent.Event

local Collections = {}

function Client.new(Identifier: string)
	assert(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	assert(not Identifiers.find(Identifier), string.format("[FastNet2]: %s already exist", Identifier))
	Process.reg(Identifier)
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = nil,
		Connected = false,
		flag = {},
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

function Client:ConnectParallel(callback: Types.callback)
	if self then
		task.desynchronize()
		self:Connect(callback)
		task.synchronize()
	end
end

function Client:Listen(callback: Types.callback)
	if self then
		self:Connect(callback)
	end
end

function Client:Wait(): number
	if self then
		return Process._ping(self.Identifier)
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
		Process.unreg(self.Identifier)
		self = nil
	end
end

function Client:Fires()
	warn("[FastNet2]: 'Fires' only can be used on server.")
end

function Client:Fire(...: any)
	Process.insert(self.Identifier, { ... })
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
		if Process.verify(self.Identifier, requestId) then
			table.remove(self.flag, requestId)
		end
		coroutine.resume(thread, nil) -- resume thread to finish and return nil as failed to retreive due over-session (expired)
	end)
	-- set new flag as checkpoint
	self.flag[requestId] = function(...)
		task.cancel(session)
		coroutine.resume(thread, ...) -- resume thread to finish and return data as successed
	end
	-- push new request
	Process.newReq(self.Identifier, requestId, { ... })
	return coroutine.yield() -- wait for return (yield)
end

Event.OnClientEvent:Connect(function(packets, secondPackets)
	if packets or secondPackets then
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
							Process.pushback(Identifier, i, Collections[Identifier].func(data))
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
	end
end)

Process.__start()

return table.freeze(Client)