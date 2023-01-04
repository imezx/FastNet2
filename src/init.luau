--!strict

-- FastNet2
-- v0.0.1-pre-alpha
warn("Initializing FastNet2")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

-- Load FastNet2 Utils
local Debug = require(script:WaitForChild("Debug"))
local Threads = require(script:WaitForChild("Thread"))
--local Encoder = require(script:WaitForChild("Encoder"))

local Nets: any
local _NetEvent: RemoteEvent
local _NetInvoke: RemoteFunction
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
if not Nets:FindFirstChild("Invoke") then
	_NetInvoke = Instance.new("RemoteFunction", Nets)
	_NetInvoke.Name = "Invoke"
else
	_NetInvoke = Nets:WaitForChild("Invoke")
end

local FastNet = {}
FastNet.__index = FastNet
FastNet.version = "0.0.1"
FastNet.build = 1

local _enableLimitingRate: boolean = false -- default: true, off it if want pure or for benchmarking
local _maxRate_perEvent: number = 500 -- default: 500
local __callbacks: any = {}
local __nets: any = {}
local _queue: any = {}
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

function FastNet:Exist(remoteName: string): boolean
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet]: Invalid type of remote name", 3, 2)
	return IsExist(remoteName)
end

function FastNet.toBestFormNumber(num: number): number | string
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

function FastNet:Get(remoteName: string, waitFor: number): any
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet]: Invalid type of remote name", 3, 2)
	if waitFor and typeof(waitFor) == "number" then
		local result, finish, _t = false, false, tick()
		local _yield = coroutine.create(function()
			repeat
				result = IsExist(remoteName)
				task.wait()
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
				func = callback or nil
			}
		else
			__callbacks[remoteName] = {
				_type = __nets[remoteName]._type,
				func = waitTill or nil
			}
		end
	end
	if __nets and __nets[remoteName]._type == "RemoteEvent" then
		function __new:Disconnect(message: string | nil)
			if __new and __callbacks[remoteName] ~= nil and __disconnected == false then
				__callbacks[remoteName] = nil
				__disconnected = true
				if message and typeof(message) == "string" and message:len() > 0 then
					Debug.__direct_debug(message:len() <= 0, string.format("[FastNet]: %s", message), 2)
				end
			end
		end
		function __new:Fire(...: any)
			local _currentIdentifier: any = _toSend[remoteName]
			if not _currentIdentifier then
				if IsExist(remoteName) then
					_currentIdentifier = _createIdentifier(remoteName)
				end
			end
			if _enableLimitingRate then
				if #_currentIdentifier > (_maxRate_perEvent or 500) then
					return -- reject
				end
			end
			if IsClient then
				table.insert(_currentIdentifier, { ... })
			elseif IsServer then
				local arg = {...}
				Debug.__direct_debug(typeof(arg[1]) == "Instance", "[FastNet]: Invalid type of player", 3, 2)
				if #arg > 0 and typeof(arg[1]) == "Instance" then
					table.insert(_currentIdentifier, { plr = Players[arg[1]], args = arg })
				end
			end
		end
		if IsServer then
			--function __new:Fire(plr: Instance, ...: any)
			--	table.insert(_toSend, { name = remoteName, plr = plr.Name, args = { ... } })
			--end
			function __new:Fires(...: any)
				table.insert(_toSend[remoteName], { plr = "All", args = { ... } })
			end
		else
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
			table.clear(__new)
		end
	end
	return __new
end

function FastNet:Create(remoteName: string, typeRemote: string)
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet]: Invalid type of remote name", 3, 2)
	Debug.__direct_debug(typeof(typeRemote) == "string", "[FastNet]: Invalid type of remote", 3, 2)
	if not IsExist(remoteName) then
		if typeof(typeRemote) == "string" then
			if typeRemote:lower() == "event" or typeRemote:lower() == "events" then
				__nets[remoteName] = {
					_type = "RemoteEvent",
					name = remoteName
				}
			elseif
				typeRemote:lower() == "invoke"
				or typeRemote:lower() == "invokes"
				or typeRemote:lower() == "function"
				or typeRemote:lower() == "functions"
			then
				__nets[remoteName] = {
					_type = "RemoteFunction",
					name = remoteName
				}
				warn("[FastNet]: RemoteFunction features is currently not available.")
			end
		end
	end
	return self:Get(remoteName, 5)
end

--function sendAll(pkg: any)
--	for i, v in ipairs(pkg) do
--		table.insert(_queue, v)
--	end
--end

if IsServer then
	_NetEvent.OnServerEvent:Connect(function(plr, pkg)
		for identifier, v in pkg do
			if #v <= 0 then
				break
			end
			if _findIdentifier(identifier) and v and IsExist(identifier) and __callbacks[identifier] ~= nil and __callbacks[identifier]["func"] ~= nil  then
				for index,data in v do
					Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
					--task.spawn(__callbacks[v[2]["name"]]["func"], v[2]["plr"], table.unpack(v[2]["args"] or {}))
				end
			end
		end
	end)
	warn("Server Initialized")
elseif IsClient then
	_NetEvent.OnClientEvent:Connect(function(pkg)
		--sendAll(pkg)
	end)
	warn("Client Initialized")
end

-- Internal Events Handler
local __t = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - __t) >= (1/60 - 0.00015) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		local to_send: any = {}
		local indexs: number = 0
		for identifier, packages in _toSend do
			if #to_send >= 100 then -- max 100 events
				break
			end
			if to_send[identifier] ~= nil or #_getIdentifier(identifier) <= 0 then
				continue
			end
			task.spawn(function()
				if IsExist(identifier) then
					to_send[identifier] = packages
					indexs += 1
				end
				_wipeIdentifier(identifier)
			end)
		end
		if IsServer then
			--local to_send_to_client: any = {}
			--local to_send_all_clients: any = {}
			--for i,v in ipairs(to_send) do
			--	task.spawn(function()
			--		if not IsExist(v["name"]) then
			--			to_send[i] = nil
			--		else
			--			if v["plr"] == "All" then
			--				table.insert(to_send_all_clients, v)
			--			else
			--				table.insert(to_send_to_client, v)
			--			end
			--		end
			--	end)
			--end
			--if #to_send_to_client > 0 then
			--	_NetEvent:FireClient(to_send_to_client)
			--	table.clear(to_send_to_client)
			--elseif #to_send_all_clients > 0 then
			--	_NetEvent:FireAllClients(to_send_all_clients)
			--	table.clear(to_send_all_clients)
			--end
		else
			if indexs > 0 then
				_NetEvent:FireServer(to_send)
			end
		end
		table.clear(to_send)
		__t = os.clock()
	end
end)

warn("FastNet2 initialized")
return table.freeze(FastNet)