--FastNet2 (Client)
local Client = {}
Client.__index = Client

local Process = require(script.Process)
local Identifiers = require(script.Identifier)
local FastSpawn = require(script.Parent.FastSpawn)
local Debug = require(script.Parent.Debug)

local Event = script.Parent:WaitForChild("Event")

local Collections = {}

function Client.new(Identifier: string)
	Debug.new(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	Debug.new(not Identifiers.find(Identifier), string.format("[FastNet2]: %s already exist", Identifier))
	Process.reg(Identifier)
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = {},
		Connected = false,
		flag = {},
		_id = nil,
	}, Client)
	return Collections[Identifier]
end

function Client:Connect(callback: (...any) -> ())
	if self then
		--Debug.new(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		Process.reg_pre_f(self.Identifier, callback)
		self.Connected = true
	end
end

function Client:ConnectParallel(callback:  (...any) -> ())
	if self then
		task.desynchronize()
		self:Connect(callback)
		task.synchronize()
	end
end

function Client:Listen(callback:  (...any) -> ())
	if self then
		self:Connect(callback)
	end
end

function Client:Wait(): number
	if self then
		return Process._ping(self.Identifier)
	end
	return 0
end

function Client:Once(callback:  (...any) -> ())
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
		Process.unreg_pre_f(self.Identifier)
		self.func = nil
	end
end

function Client:Destroy()
	self:Disconnect()
	if self then
		Process.unreg(self.Identifier)
		self = setmetatable(self, nil)
	end
end

function Client:Fire(...: any)
	Process.insert(self.Identifier, { ... })
end

function Client:Fires(...: any)
	warn("[FastNet2]: 'Fires' only can be used on server.")
end

function Client:Pull(expire: number, ...: any)
	Debug.new(typeof(expire) == "number", "[FastNet2]: expire argument must be a number.")
	Debug.new(expire > 1, "[FastNet2]: expire argument must be minimum 2.")
	local thread, requestId = coroutine.running(), tostring(#self.flag + 1)
	local session = task.delay(expire, function()
		-- session expire
		-- removing and clear entire requests point
		if self.flag[requestId] then
			table.remove(self.flag, requestId)
		end
		if Process.verify(self.Identifier, requestId) then
			table.remove(self.flag, requestId)
		end
		task.spawn(thread, nil) -- resume thread to finish and return nil as failed to retreive due over-session (expired)
	end)
	-- set new flag as checkpoint
	self.flag[requestId] = function(...)
		task.cancel(session)
		task.spawn(thread, ...) -- resume thread to finish and return data as successed
	end
	-- push new request
	Process.newReq(self.Identifier, requestId, { ... })
	return coroutine.yield() -- wait for return (yield)
end

Event.OnClientEvent:Connect(function(packets: any, secondPackets: any)
	if packets or secondPackets then
		if typeof(packets) == "table" then
			for Identifier, packet in packets do
				if Collections[Identifier] and Collections[Identifier].Connected then
					for _, data in packet do
						FastSpawn(Collections[Identifier].func :: any, table.unpack(data))
					end
				else
					-- throw to Process as pre-process
					Process._pre(Identifier, packet)
				end
			end
			table.clear(packets)
		elseif typeof(packets) == "string" then
			if packets == "0" then
				for Identifier, packet in secondPackets do
					if Collections[Identifier] and Collections[Identifier].Connected then
						for i, data in packet do
							FastSpawn(Process.pushback, Identifier, i, Collections[Identifier].func(table.unpack(data)))
						end
					else
						-- throw to Process as pre-process
						Process._pre_p(Identifier, packet)
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
	end
end)

Process.__start()

return table.freeze(Client) :: typeof(Client)