-- FastNet2 (Server)
local Server = {}
Server.__index = Server

local Process = require(script.Process)
local Identifiers = require(script.Identifier)
local FastSpawn = require(script.Parent.FastSpawn)
local Debug = require(script.Parent.Debug)

local Event = script.Parent:WaitForChild("Event")

local Collections = {}

function Server.new(Identifier: string)
	Debug.new(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string")
	Debug.new(not Identifiers.find(Identifier), string.format("[FastNet2]: %s already exist", Identifier))
	Process.reg(Identifier)
	Collections[Identifier] = setmetatable({
		Identifier = Identifier,
		func = function(...: any): (...any) end,
		Connected = false,
		flag = {},
	}, Server)
	return Collections[Identifier]
end

function Server:Connect(callback:  (...any) -> ())
	if self then
		Debug.new(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier))
		self.func = callback
		Process.reg_pre_f(self.Identifier, callback)
		self.Connected = true
	end
end

function Server:ConnectParallel(callback:  (...any) -> ())
	if self then
		task.desynchronize()
		self:Connect(callback)
		task.synchronize()
	end
end

function Server:Listen(callback:  (...any) -> ())
	if self then
		self:Connect(callback)
	end
end

function Server:Wait(): number
	if self then
		return Process._ping(self.Identifier)
	end
	return 0
end

function Server:Once(callback:  (...any) -> ())
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
		Process.unreg_pre_f(self.Identifier)
		self.func = nil
	end
end

function Server:Destroy()
	self:Disconnect()
	if self then
		Process.unreg(self.Identifier)
		self = setmetatable(self, nil)
	end
end

function Server:Fire(player: Player, ...: any)
	Process.s_insert(self.Identifier, player, { ... })
end

function Server:Fires(...: any)
	Process.insert(self.Identifier, { ... })
end

function Server:Pull(expire: number, player: Player, ...: any)
	Debug.new(typeof(expire) == "number", "[FastNet2]: expire argument must be a number.")
	Debug.new(expire > 1, "[FastNet2]: expire argument must be minimum 2.")
	Debug.new(player:IsA("Player"), "[FastNet2]: player argument must be a Player.")
	local thread, requestId = coroutine.running(), tostring(#self.flag + 1)
	local session = task.delay(expire, function()
		-- session expire
		-- removing and clear entire requests point
		if self.flag[requestId] then
			table.remove(self.flag, requestId)
		end
		if Process.verify(self.Identifier, player, requestId) then
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
	Process.newReq(self.Identifier, requestId, player, { ... })
	return coroutine.yield() -- wait for return (yield)
end

Event.OnServerEvent:Connect(function(player: Player, packets: any, secondPackets: any)
	if player and (packets or secondPackets) then
		if typeof(packets) == "table" then
			for Identifier, packet in packets do
				if Collections[Identifier] and Collections[Identifier].Connected then
					for _, data in packet do
						FastSpawn(Collections[Identifier].func, player, table.unpack(data))
					end
				else
					-- throw to Process as pre-process
					Process._pre(Identifier, player, packet)
				end
			end
			table.clear(packets)
		elseif typeof(packets) == "string" then
			if packets == "0" then
				for Identifier, packet in secondPackets do
					if Collections[Identifier] and Collections[Identifier].Connected then
						for i, data in packet do
							Process.pushback(Identifier, player.Name, i, Collections[Identifier].func(player, table.unpack(data)))
						end
					else
						-- throw to Process as pre-process
						Process._pre_p(Identifier, player, packet)
					end
				end
				table.clear(secondPackets)
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
				table.clear(secondPackets)
			elseif packets == "2" then
				if not script.Parent:WaitForChild("_Players"):GetAttribute(tostring(secondPackets)) then
					script.Parent:WaitForChild("_Players"):SetAttribute(tostring(secondPackets), true)
				end
			end
		end
	end
end)

Process.__start()

return table.freeze(Server) :: typeof(Server)