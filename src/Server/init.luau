--!native
-- FastNet2 (Server)
local Server = {}
Server.__index = Server

local Process = require(script.Process)
local Identifiers = require(script.Identifier)
local FastSpawn = require(script.Parent.FastSpawn)
local Debug = require(script.Parent.Debug)
local Util = require(script.Parent.Util)

local Event = script.Parent:WaitForChild("Event")

local Collections = {}

--[[**
	Create new Server Connection

	@param Identifier The name of Connection (Identifier)

	@returns metatable of connection
**--]]

function Server.new(Identifier: string)
	Debug.new(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string", 0)
	Debug.new(not Identifiers.find(Util.ser(Identifier)), string.format("[FastNet2]: %s already exist", Identifier), 0)
	Process.reg(Util.ser(Identifier))
	Collections[Util.ser(Identifier)] = setmetatable({
		Identifier = Util.ser(Identifier),
		func = function(...: any): (...any) end,
		Connected = false,
		flag = {},
	}, Server)
	return Collections[Util.ser(Identifier)]
end

--[[**
	Connect a connection

	@param callback this must be a function with any arguments
**--]]

function Server:Connect(callback:  (...any) -> ())
	Debug.new(not self.Connected, string.format("[FastNet2]: %s already connected", self.Identifier), 0)
	self.func = callback
	Process.reg_pre_f(self.Identifier, callback)
	self.Connected = true
end

--[[**
	Connect a connection (Luau Parralel)

	@param callback this must be a function with any arguments
**--]]

function Server:ConnectParallel(callback:  (...any) -> ())
	task.desynchronize()
	self:Connect(callback)
	task.synchronize()
end

--[[**
	Connect a connection

	@param callback this must be a function with any arguments
**--]]

function Server:Listen(callback:  (...any) -> ())
	self:Connect(callback)
end

--[[**
	Wait Connection is being process
**--]]

function Server:Wait(): number
	return Process._ping(self.Identifier)
end

--[[**
	Connection a connection for once only
	
	@param callback this must be a function with any arguments
**--]]

function Server:Once(callback:  (...any) -> ())
	if not self.Connected then
		self.func = function(...)
			self:Disconnect()
			task.spawn(callback, ...)
		end
		self.Connected = true
	end
end

--[[**
	Disconnect connection that is connected
**--]]

function Server:Disconnect()
	if self.Connected then
		self.Connected = false
		Process.unreg_pre_f(self.Identifier)
		self.func = nil
	end
end

--[[**
	Distroy & Disconnect the connection
**--]]

function Server:Destroy()
	self:Disconnect()
	Process.unreg(self.Identifier)
	setmetatable(self, nil)
end

--[[**
	Send/Fire to a connection
	
	@params player a Player Instance
	@params ... any parameters to sent
**--]]

function Server:Fire(player: Player, ...: any)
	Process.s_insert(self.Identifier, player, { ... })
end

--[[**
	Send/Fire to a connection
	
	@params ... any parameters to sent
**--]]

function Server:Fires(...: any)
	Process.insert(self.Identifier, { ... })
end


--[[**
	Invoke/Pull to a connection
	
	@params timeout this is a timeout/session limit argument
	@params player a Player Instance
	@params ... any parameters to sent
**--]]

function Server:Pull(timeout: number, player: Player, ...: any)
	Debug.new(typeof(timeout) == "number", "[FastNet2]: expire argument must be a number.", 0)
	Debug.new(timeout > 1, "[FastNet2]: expire argument must be minimum 2.", 0)
	Debug.new(player:IsA("Player"), "[FastNet2]: player argument must be a Player.", 0)
	Debug.new(#{...} > 0, "[FastNet2]: Unable to invoke without data", 0)
	local thread, requestId = coroutine.running(), string.pack("I5", Util.uniqueNum())
	local session = task.delay(timeout, function()
		-- session expire
		-- removing and clear entire requests point
		if Process.verify(self.Identifier, player, requestId) or self.flag[requestId] then
			self.flag[requestId] = nil
		end
		task.spawn(thread, nil) -- resume thread to finish and return nil as failed to retreive due over-session (expired)
	end)
	-- set new flag as checkpoint
	self.flag[requestId] = function(...)
		self.flag[requestId] = nil
		task.cancel(session)
		task.spawn(thread, ...) -- resume thread to finish and return data as successed
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
							FastSpawn(Process.pushback, Identifier, player.Name, i, Collections[Identifier].func(player, table.unpack(data)))
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
				if not Event:GetAttribute(tostring(secondPackets)) then
					Event:SetAttribute(tostring(secondPackets), true)
				end
			end
		end
	end
end)

Process.__start()

return table.freeze(Server) :: typeof(Server)