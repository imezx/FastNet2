--!strict

-- FastNet2
-- v0.0.2-pre-alpha
warn("Initializing FastNet2")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

-- Load Utils
local Debug = require(script:WaitForChild("Debug"))
local Threads = require(script:WaitForChild("Thread"))

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

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = "0.0.2"
FastNet2.build = 2

local _enableLimitingRate: boolean = false -- default: true, off it if want pure or for benchmarking
local _maxRate_perEvent: number = 500 -- default: 500
local __callbacks: any = {}
local __nets: any = {}
local _toSend: any = {}

if _maxRate_perEvent < 1 or _maxRate_perEvent == math.huge then
	_maxRate_perEvent = 500
end

function IsExist(remoteName: string): boolean
	if __nets[remoteName] then
		return true
	end
	return false
end

function FastNet2:Exist(remoteName: string): boolean
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	return IsExist(remoteName)
end

function FastNet2.toBestFormNumber(num: number): number | string
	local _tostring = tostring(num)
	if #_tostring <= 7 then
		return _tostring
	else
		return num
	end
end

function _findIdentifier(IdentifierName: string): boolean
	return _toSend[IdentifierName] and true or false
end
function _getIdentifier(IdentifierName: string): any
	if _findIdentifier(IdentifierName) then
		return _toSend[IdentifierName]
	end
	return {}
end
function _createIdentifier(IdentifierName: string): boolean
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
function _removeIdentifier(IdentifierName: string)
	if _findIdentifier(IdentifierName) then
		_wipeIdentifier(IdentifierName) -- clear first
		_toSend[IdentifierName] = nil
	end
	return _findIdentifier(IdentifierName)
end

function FastNet2:Get(remoteName: string, waitFor: number): any
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	if waitFor and typeof(waitFor) == "number" then
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
	function __new:Listen(waitTill: boolean | any, callback: any)
		if typeof(waitTill) == "boolean" and waitTill == true then
			repeat
				task.wait()
			until __disconnected == false and IsExist(remoteName) == true
			__callbacks[remoteName] = {
				_type = __nets[remoteName]._type,
				func = callback or nil,
			}
		else
			__callbacks[remoteName] = {
				_type = __nets[remoteName]._type,
				func = waitTill or nil,
			}
		end
	end
	if __nets and __nets[remoteName]._type == "RemoteEvent" then
		function __new:Disconnect(message: string | nil)
			if __new and __callbacks[remoteName] ~= nil and __disconnected == false then
				__callbacks[remoteName] = nil
				__disconnected = true
				if message and typeof(message) == "string" and message:len() > 0 then
					Debug.__direct_debug(message:len() <= 0, string.format("[FastNet2]: %s", message), 2)
				end
			end
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
				table.insert(_currentIdentifier, { "Client", { ... } })
			end
		end
		function __new:Disconnected()
			return __disconnected
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
	return table.freeze(__new)
end

function FastNet2:Create(remoteName: string, typeRemote: string)
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

if IsServer then
	_NetEvent.OnServerEvent:Connect(function(plr, pkg)
		for identifier, v in pkg do
			if #v <= 0 then
				break
			end
			if
				_findIdentifier(identifier)
				and v
				and IsExist(identifier)
				and __callbacks[identifier] ~= nil
				and __callbacks[identifier]["func"] ~= nil
			then
				for index, data in v do
					Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
				end
			end
		end
	end)
	warn("Server initialized")
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
					for index, data in _data do
						Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
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
					Threads(__callbacks[_data[1]]["func"], table.unpack(_data[2] or {}))
				end
			end
		end
	end)
	warn("Client initialized")
end

-- Internal Events Handler
local __t = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - __t) >= (1 / 60 - 0.00015) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		local to_send: any = {
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
			if IsClient and typeof(packages[1]) == "string" then -- is client
				if __reach_c_max then
					continue
				end
				if to_send["Client"][identifier] ~= nil or #_getIdentifier(identifier) <= 0 then
					continue
				end
				task.spawn(function()
					if IsExist(identifier) then
						to_send["Client"][identifier] = packages[2]
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
			for identifier, _pkgs in to_send["Server"] do
				for index, data in _pkgs do
					task.spawn(function()
						if typeof(data[1]) == "Instance" then
							if not to_send_to_client[identifier] then
								to_send_to_client[identifier] = {}
								to_send_to_client[identifier][data[1]] = {}
							end
							table.insert(to_send_to_client[identifier][data[1]], data[2])
						else
							if not to_send_all_clients[identifier] then
								to_send_all_clients[identifier] = {}
							end
							table.insert(to_send_all_clients[identifier], data[2])
						end
					end)
				end
			end
			_NetEvent:FireAllClients(to_send_all_clients)
			table.clear(to_send_all_clients)
			for identifier, pkg in to_send_to_client do
				for player, _data in pkg do
					local _convert = {}
					_convert[identifier] = _data
					_NetEvent:FireClient(player, _convert)
				end
			end
			table.clear(to_send_to_client)
		elseif IsClient and __Cindex > 0 then
			_NetEvent:FireServer(to_send["Client"])
		end
		table.clear(to_send) -- prevent memory leaks?
		__t = os.clock()
	end
end)

warn("FastNet2 initialized")
return table.freeze(FastNet2)