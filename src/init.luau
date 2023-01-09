--!strict

-- FastNet2
-- v0.0.4-pre-alpha
local __load_s: any = tick()
local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = "0.0.4"
FastNet2.build = 4

type Tany = { [any]: any }

--// Settings
local _enableLimitingRate: boolean = false -- default: true, off it if want pure or for benchmarking
local _maxRate_perEvent: number = 500 -- default: 500
local __threads: number = 250  -- default: 250
local __callbacks: Tany = {}
local __nets: Tany = {}
local _toSend: Tany = {}

if __threads < 100 then
	__threads = 100
end

--// Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

--// Load Utils
local Debug = require(script:WaitForChild("Debug"))
local Threads = require(script:WaitForChild("Thread")).__start(__threads)

local Nets: any
local _NetEvent: RemoteEvent
-- local _NetInvoke: RemoteFunction
if not script:FindFirstChild("Net") then
	Nets = Instance.new("Folder", script)
	Nets.Name = "Net"
else
	Nets = script:WaitForChild("Net", 5)
end
if not Nets:FindFirstChild("Event") then
	_NetEvent = Instance.new("RemoteEvent", Nets)
	_NetEvent.Name = "Event"
else
	_NetEvent = Nets:WaitForChild("Event")
end
-- if not Nets:FindFirstChild("Invoke") then
-- 	_NetInvoke = Instance.new("RemoteFunction", Nets)
-- 	_NetInvoke.Name = "Invoke"
-- else
-- 	_NetInvoke = Nets:WaitForChild("Invoke")
-- end

if _maxRate_perEvent < 1 or _maxRate_perEvent == math.huge then
	_maxRate_perEvent = 500
end

--// Internal Functions
function __getProvider(toBool: boolean|nil): any
	if typeof(toBool) == "boolean" and toBool == true then
		return {IsServer, IsClient}
	end
	return IsClient and "Client" or "Server"
end

function IsExist(remoteName: string): boolean
	if __nets[remoteName] then
		return true
	end
	return false
end

function _findIdentifier(IdentifierName: string): boolean
	return _toSend[IdentifierName] and true or false
end
function _getIdentifier(IdentifierName: string): Tany | {}
	if _findIdentifier(IdentifierName) then
		return _toSend[IdentifierName]
	end
	return {}
end
function _createIdentifier(IdentifierName: string): Tany
	if IsExist(IdentifierName) and not _findIdentifier(IdentifierName) then
		_toSend[IdentifierName] = {}
	end
	return _getIdentifier(IdentifierName)
end
function _wipeIdentifier(IdentifierName: string)
	if _findIdentifier(IdentifierName) then
		_toSend[IdentifierName] = {}
	end
end
function _removeIdentifier(IdentifierName: string): boolean
	if _findIdentifier(IdentifierName) then
		_wipeIdentifier(IdentifierName) -- clear first
		_toSend[IdentifierName] = nil
	end
	return _findIdentifier(IdentifierName)
end

--// APIs
function FastNet2.getProvider(toBool: boolean|nil): any
	return __getProvider(toBool or false)
end

function FastNet2.toBestFormNumber(num: number): number | string
	local _tostring = tostring(num)
	if #_tostring <= 7 then
		return _tostring
	else
		return num
	end
end

function FastNet2:Wait(): number
	--[[
	Somereason just use PostSimulator as Heartbeat because Heartbeat only fire after Render Signal fire here why if the server/client dropped frame
	could be bad, PostSimulator is the new of Heartbeat, PostSimultion dont need to wait until Render Signal fired.
	PostSimulation is 1/60 or print(RunService.PostSimulation:Wait())
	]]--
	return RunService.PostSimulation:Wait() -- 60 frame / 0.0166s / 16.66ms
end
function FastNet2:wait(): number
	return self:Wait()
end

function FastNet2.Dsend(): number
	return StatsService.DataSendKbps
end
function FastNet2.Dreceive(): number
	return StatsService.DataReceiveKbps
end

function FastNet2:Exist(remoteName: string): boolean
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	return IsExist(remoteName)
end

function FastNet2:Get(remoteName: string, waitFor: number): Tany
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	if waitFor and typeof(waitFor) == "number" then
		if waitFor < 5 then
			waitFor = 5
		end
		local result, finish, _t = false, false, tick()
		local _yield = coroutine.create(function()
			repeat
				result = IsExist(remoteName)
				task.wait(1 / 90)
			until result == true
			finish = true
		end)
		coroutine.resume(_yield)
		while finish == false do
			if (tick() - _t) >= waitFor then
				finish = true
				coroutine.close(_yield)
				break
			end
		end
	end
	_createIdentifier(remoteName)
	local __new = {}
	local __disconnected = false
	-- functions
	function __new:Wait() -- EXPERIMENTAL
		local _now,this = tick(), math.random(math.random(29, 97), math.random(1033, math.random(13301, 255067)))
		local val,_on = 0,true
		__callbacks[remoteName]["_signal"..this] = function()
			val = tick()
			_on = false
		end
		repeat task.wait() until _on == false
		return (val-_now)
	end
	function __new:wait()
		return self:Wait()
	end
	function __new:Listen(waitTill: boolean | any, callback: any)
		if typeof(waitTill) == "boolean" and waitTill == true then
			repeat
				task.wait()
			until __disconnected == false and IsExist(remoteName) == true
			__callbacks[remoteName] = {
				func = callback or nil,
			}
		else
			__callbacks[remoteName] = {
				func = waitTill or nil,
			}
		end
		__callbacks[remoteName]["_type"] = __nets[remoteName]._type
	end
	function __new:listen(waitTill: boolean | any, callbacks: any)
		self:Listen(waitTill, callbacks)
	end
	if __nets and __nets[remoteName]._type == "RemoteEvent" then
		function __new:Once(waitTill: boolean | any, callbacks: any)
			self:Listen(waitTill, callbacks)
			if __callbacks[remoteName] then
				__callbacks[remoteName]["_once"] = true
			end
		end
		function __new:once(waitTill: boolean | any, callbacks: any)
			self:Once(waitTill, callbacks)
		end
		function __new:Disconnect(message: string | nil)
			if __new and __callbacks[remoteName] ~= nil and __disconnected == false then
				__callbacks[remoteName] = nil
				__disconnected = true
				if message and typeof(message) == "string" and message:len() > 0 then
					Debug.__direct_debug(message:len() <= 0, string.format("[FastNet2]: %s", message), 2)
				end
			end
		end
		function __new:disconnect(message: string | nil)
			self:Disconnect(message)
		end
		if IsServer then
			function __new:Fires(...: any)
				local _currentIdentifier: any = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				table.insert(_currentIdentifier, { "All", { ... } })
			end
			function __new:Fire(player: Player, ...: any)
				local _currentIdentifier: any = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				table.insert(_currentIdentifier, { player, { ... } })
			end
		else
			function __new:Fire(...: any)
				local _currentIdentifier: any = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				if _enableLimitingRate and #_currentIdentifier > (_maxRate_perEvent or 500) then -- rate limit for client only
					return -- reject
				end
				table.insert(_currentIdentifier, { ... })
			end
		end
		function __new:Disconnected(): boolean
			return __disconnected
		end
		function __new:disconnected(): boolean
			return self:Disconnected()
		end
	end
	function __new:Destroy()
		if __nets[remoteName] ~= nil then
			__nets[remoteName] = nil
			__callbacks[remoteName] = nil
			__disconnected = true
			_removeIdentifier(remoteName)
		end
	end
	function __new:destroy()
		self:Destroy()
	end
	return table.freeze(__new)
end

function FastNet2:get(remoteName: string, waitFor: number): Tany
	return self:Get(remoteName, waitFor or 5)
end

function FastNet2:Create(remoteName: string, typeRemote: string): Tany
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	Debug.__direct_debug(typeof(typeRemote) == "string", "[FastNet2]: Invalid type of remote", 3, 2)
	if not IsExist(remoteName) then
		if typeof(typeRemote) == "string" then
			typeRemote = typeRemote:lower()
			if typeRemote == "event" or typeRemote == "events" or typeRemote == "remoteevent" or typeRemote == "remoteevents" then
				__nets[remoteName] = {
					_type = "RemoteEvent",
					name = remoteName,
				}
			elseif
				typeRemote == "invoke"
				or typeRemote == "invokes"
				or typeRemote == "function"
				or typeRemote == "functions"
				or typeRemote == "remotefunction"
				or typeRemote == "remotefunctions"
			then
				-- __nets[remoteName] = {
				-- 	_type = "RemoteFunction",
				-- 	name = remoteName
				-- }
				warn("[FastNet2]: RemoteFunction features is currently not available.")
			end
		end
	end
	return self:Get(remoteName, 5)
end

function FastNet2:create(remoteName: string, typeRemote: string): Tany
	return self:Create(remoteName, typeRemote)
end

if IsServer then
	_NetEvent.OnServerEvent:Connect(function(plr, pkg)
		for identifier, v in pkg do
			if typeof(identifier) == "string" then
				if #v <= 0 then
					break
				end
				if
					_findIdentifier(identifier)
					and IsExist(identifier)
					and __callbacks[identifier] ~= nil
					and __callbacks[identifier]["func"] ~= nil
				then
					if __callbacks[identifier] ~= nil then
						for index, data in v do
							if __callbacks[identifier] ~= nil then
								Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
								if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
									__callbacks[identifier] = nil
								end
							end
						end
						task.spawn(function()
							for i,v in __callbacks[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									v()
								end
							end
						end)
					end
				end
			end
		end
	end)
elseif IsClient then
	_NetEvent.OnClientEvent:Connect(function(pkg)
		for identifier, _data in pkg do
			if typeof(identifier) == "string" then
				if #_data[1] <= 0 then
					break
				end
				if
					_findIdentifier(identifier)
					and IsExist(identifier)
					and __callbacks[identifier] ~= nil
					and __callbacks[identifier]["func"] ~= nil
				then
					if __callbacks[identifier] ~= nil then
						for index, data in _data do
							if __callbacks[identifier] ~= nil then
								Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
								if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
									__callbacks[identifier] = nil
								end
							end
						end
						task.spawn(function()
							for i,v in __callbacks[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									v()
								end
							end
						end)
					end
				end
			else
				if #_data[2] <= 0 then
					break
				end
				if
					_findIdentifier(_data[1])
					and IsExist(_data[1])
					and __callbacks[_data[1]] ~= nil
					and __callbacks[_data[1]]["func"] ~= nil
				then
					if __callbacks[identifier] ~= nil then
						Threads(__callbacks[_data[1]]["func"], table.unpack(_data[2] or {}))
						if __callbacks[_data[1]]["_once"] ~= nil and __callbacks[_data[1]]["_once"] == true then
							__callbacks[_data[1]] = nil
						end
						task.spawn(function()
							for i,v in __callbacks[_data[1]] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									v()
								end
							end
						end)
					end
				end
			end
		end
	end)
end

-- Internal Events Handler
local __t = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - __t) >= (1 / 60 - 0.00015) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		local to_send: Tany = {
			["Server"] = {},
			["Client"] = {},
		}
		local __reach_s_max: boolean = false
		local __reach_c_max: boolean = false
		local __Sindex: number = 0
		local __Cindex: number = 0
		for identifier, packages in _toSend do
			if __reach_s_max and __reach_c_max then
				break
			end
			if not __reach_s_max then
				if #to_send["Server"] >= 100 then -- max 100 events per side
					__reach_s_max = true
					continue
				end
			end
			if not __reach_c_max then
				if #to_send["Client"] >= 100 then -- max 100 events per side
					__reach_c_max = true
					continue
				end
			end
			if IsClient then -- is client
				if __reach_c_max then
					continue
				end
				if to_send["Client"][identifier] ~= nil or #_getIdentifier(identifier) <= 0 then
					continue
				end
				task.spawn(function()
					if IsExist(identifier) then
						to_send["Client"][identifier] = packages
						__Cindex += 1
					end
					_wipeIdentifier(identifier)
				end)
			elseif IsServer then -- is server
				if __reach_s_max then
					continue
				end
				if to_send["Server"][identifier] ~= nil or #_getIdentifier(identifier) <= 0 then
					continue
				end
				task.spawn(function()
					if IsExist(identifier) then
						to_send["Server"][identifier] = packages
						__Sindex += 1
					end
					_wipeIdentifier(identifier)
				end)
			end
		end
		if IsServer and __Sindex > 0 then
			local to_send_to_client: any = {}
			local to_send_all_clients: any = {}
			local to_send_all_indexs: number = 0
			local to_send_indexs: number = 0
			for identifier, _pkgs in to_send["Server"] do
				for index, data in _pkgs do
					if typeof(data[1]) == "Instance" then
						if not to_send_to_client[identifier] then
							to_send_to_client[identifier] = {}
							to_send_to_client[identifier][data[1]] = {}
						end
						table.insert(to_send_to_client[identifier][data[1]], data[2])
						to_send_indexs += 1
					else
						if not to_send_all_clients[identifier] then
							to_send_all_clients[identifier] = {}
						end
						table.insert(to_send_all_clients[identifier], data[2])
						to_send_all_indexs += 1
					end
				end
			end
			if to_send_all_indexs > 0 then
				_NetEvent:FireAllClients(to_send_all_clients)
				table.clear(to_send_all_clients)
			end
			if to_send_indexs > 0 then
				for identifier, pkg in to_send_to_client do
					for player, _data in pkg do
						local _convert = {}
						_convert[identifier] = _data
						_NetEvent:FireClient(player, _convert)
					end
				end
				table.clear(to_send_to_client)
			end
		elseif IsClient and __Cindex > 0 then
			_NetEvent:FireServer(to_send["Client"])
		end
		table.clear(to_send) -- prevent memory leaks?
		__t = os.clock()
	end
end)

warn(string.format("FastNet2 initialized [%s | %sms]", __getProvider(), (tick() - __load_s)*1000))
return table.freeze(FastNet2)