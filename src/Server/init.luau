--!native
-- FastNet2 (Server)
local Server = {}
Server.__index = Server

local Players = game:GetService("Players")

local Process = require(script.Process)
local Identifiers = require(script.Identifier)
local FastSpawn = require(script.Parent.FastSpawn)
local Debug = require(script.Parent.Debug)
local Util = require(script.Parent.Util)

local Event: RemoteEvent = script.Parent:WaitForChild("Event")
local UnreliableEvent: UnreliableRemoteEvent = script.Parent:WaitForChild("UnreliableEvent")

local Collections = {}

--[[**
	Create new Server Connection

	@param Identifier The name of Connection (Identifier)

	@returns metatable of connection
**--]]

function Server.new(Identifier: string, reliable: boolean)
	Debug.new(typeof(Identifier) == "string", "[FastNet2]: Identifier must be string", 0)
	if not Identifiers.find(Util.ser(Identifier)) then
		Process.reg(Util.ser(Identifier), reliable or true)
		Collections[Util.ser(Identifier)] = setmetatable({
			_origin = Identifier,
			Identifier = Util.ser(Identifier),
			func = function(...: any): (...any) end,
			Connected = false,
			Reliable = reliable or true,
			flag = {},
		}, Server)
	end
	return Collections[Util.ser(Identifier)]
end

--[[**
	Connect a connection

	@param callback this must be a function with any arguments
**--]]

function Server:Connect(callback:  (...any) -> ())
	Debug.new(not self.Connected, string.format("[FastNet2]: %s already connected", self._origin), 0)
	self.func = callback
	Process.reg_pre_f(self.Identifier, callback)
	self.Connected = true
end

--[[**
	Connect a connection (Luau Parralel)
	This only works with Actor Instance

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
	if self.Connected then return end
	self.func = function(...)
		self:Disconnect()
		task.spawn(callback, ...)
	end
	Process.reg_pre_f(self.Identifier, callback)
	self.Connected = true
end

--[[**
	Disconnect connection that is connected
**--]]

function Server:Disconnect()
	if not self.Connected then return end
	self.Connected = false
	Process.unreg_pre_f(self.Identifier)
	self.func = nil
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

function Server:Invoke(timeout: number, player: Player, ...: any)
	Debug.new(typeof(timeout) == "number", "[FastNet2]: expire argument must be a number.", 0)
	Debug.new(timeout >= 1, "[FastNet2]: expire argument must be minimum 1.", 0)
	Debug.new(player:IsA("Player"), "[FastNet2]: player argument must be a Player.", 0)
	Debug.new(#{...} > 0, "[FastNet2]: Unable to invoke without data", 0)
	local thread, requestId = coroutine.running(), string.pack("I5", Util.uniqueNum())
	local session = Util.Session(timeout)
	:After(function(e)
		-- session expire
		-- removing and clear entire requests point
		if Process.verify(self.Identifier, player, requestId) or self.flag[requestId] then
			self.flag[requestId] = nil
		end
		task.spawn(thread, e) -- resume thread to finish and return nil as failed to retreive due over-session (expired)
	end, nil)
	-- set new flag as checkpoint
	self.flag[requestId] = function(...)
		self.flag[requestId] = nil
		session:Cancel()
		task.spawn(thread, ...) -- resume thread to finish and return data as successed
	end
	-- push new request
	Process.newReq(self.Identifier, requestId, player, { ... })
	return coroutine.yield() -- wait for return (yield)
end

local function OnServerReceive(player: Player, packets: any, secondPackets: any)
	if player and (packets or secondPackets) then
		if typeof(packets) == "table" then
			for Identifier, packet in packets do
				if Collections[Identifier] and Collections[Identifier].Connected then
					for _, data in packet do
						FastSpawn(Collections[Identifier].func, player, table.unpack(data))
					end
				elseif Collections[Identifier].Reliable then
					-- throw to Process as pre-process
					Process._pre(Identifier, player, packet)
				end
			end
			table.clear(packets)
		elseif typeof(packets) == "string" and secondPackets then
			if packets == "0" then
				for Identifier, packet in secondPackets do
					if Collections[Identifier] and Collections[Identifier].Connected then
						for i, data in packet do
							FastSpawn(Process.pushback, Identifier, player.Name, i, Collections[Identifier].func(player, table.unpack(data)))
						end
					elseif Collections[Identifier].Reliable then
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
			elseif packets == "2" and typeof(secondPackets) == "string" then
				if Players:FindFirstChild(secondPackets) and not Event:GetAttribute(secondPackets) then
					Event:SetAttribute(secondPackets, true)
				end
			end
		end
	end
end

Event.OnServerEvent:Connect(OnServerReceive)
UnreliableEvent.OnServerEvent:Connect(OnServerReceive)

Process.__start()

return table.freeze(Server) :: typeof(Server)