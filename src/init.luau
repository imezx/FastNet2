--!strict

-- FastNet2
-- v0.0.7-pre-alpha
local __load_s: any = tick()
local Core = {}
local FastNet2 = {}
Core.__index = Core
FastNet2.__index = FastNet2
FastNet2.version = "0.0.7"
FastNet2.build = 7

type Tany = { [any]: any }

--// Settings
local _enableLimitingRate: boolean = false -- default: true, off it if want pure or for benchmarking
local _maxRate_perEvent: number = 500 -- default: 500
local __threads: number = 350  -- default: 300
local __callbacks: Tany = {}
local __nets: Tany = {}
local _toSend: Tany = {}
local _signals: any = {}
local _reDo: any = {}

local initialized = false

local __currentMode: number = 2
local LevelModes: Tany = {
	[1] = "Low",
	[2] = "Default",
	[3] = "High",
	[4] = "Max",
}

if __threads < 200 or __threads >= 1.5e3 then
	__threads = 200
end

--// Services
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

--// Load Utils
local Debug = require(script:WaitForChild("Debug"))
local Threads: any = require(script:WaitForChild("Thread"))

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

if _maxRate_perEvent < 1 or _maxRate_perEvent >= math.huge then
	_maxRate_perEvent = 500
end

--// Internal Functions
function reConfigure(level: number?): string -- EXPERIMENTAL FEATURE
	Debug.__direct_debug(initialized == false, "[FastNet2]: couldn't re-configure internal system settings [Already set].", 2)
	if not initialized then
		initialized = true
		if level ~= nil and typeof(level) == "number" then
			__currentMode = level
		end
		if not LevelModes[__currentMode] then
			__currentMode = 2
		end
		if __currentMode == 4 then
			__threads = 1500
		elseif __currentMode == 3 then
			__threads = 650
		elseif __currentMode == 2 then
			__threads = 350
		else
			__threads = 200
		end
		Threads = Threads.__start(__threads)
	end
	if __threads < 200 or __threads >= 1.5e3 then
		__threads = 200
	end
	return LevelModes[__currentMode]
end
function __getProvider(toBool: boolean?): any
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

function _createId(): number
	return math.random(math.random(29, 97), math.random(1033, math.random(13301, 255067)))
end

function _findIdentifier(IdentifierName: string): boolean
	return _toSend[IdentifierName] and true or false
end
function _getIdentifier(IdentifierName: string): Tany
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
function _createSignal(remoteName: string)
	Debug.__direct_debug(__nets[remoteName] ~= nil, "[FastNet2]: Couldn't create signal, Spesific remote not exists.", 2)
	if __nets[remoteName] and _signals[remoteName] == nil then
		_signals[remoteName] = {}
	end
end

--// APIs
function Core.init(enableDebugs: boolean, levelForPrimaryModeThreads: number?): any
	Debug.__direct_debug(typeof(enableDebugs) == "boolean", "[FastNet2]: Invalid type of debug option", 2)
	if levelForPrimaryModeThreads ~= nil then
		Debug.__direct_debug(typeof(levelForPrimaryModeThreads) == "number", "[FastNet2]: Invalid type of level mode", 2)
	end
	Debug.set_debug(enableDebugs or true)
	reConfigure(levelForPrimaryModeThreads)
	return table.freeze(FastNet2)
end

function FastNet2.getdebugcache(maxrange: number): Tany
	return Debug.get_debugs_inrange(maxrange or 100)
end

function FastNet2.getProvider(toBool: boolean?): any
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

function FastNet2.up(): number
	return StatsService.DataSendKbps
end
function FastNet2.down(): number
	return StatsService.DataReceiveKbps
end

function FastNet2:Exist(remoteName: string): boolean
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	return IsExist(remoteName)
end

function FastNet2:Get(remoteName: string, waitFor: number?): Tany
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	Debug.__direct_debug(__nets[remoteName] ~= nil, "[FastNet2]: Remote not found, Require :Create first.", 2)
	if waitFor and typeof(waitFor) == "number" then
		if waitFor < 5 then
			waitFor = 5
		end
		local result, finish, _t = false, false, tick()
		local _yield = task.spawn(function()
			repeat
				result = IsExist(remoteName)
				task.wait()
			until result == true
			finish = true
		end)
		while (finish == false) do
			if (tick() - _t) >= waitFor then
				finish = true
				task.cancel(_yield)
				break
			end
			task.wait()
		end
	end
	_createSignal(remoteName)
	_createIdentifier(remoteName)
	local __new: Tany = {}
	local __disconnected = false
	-- functions
	function __new:Wait() -- EXPERIMENTAL
		local _now,this = tick(), _createId()
		local val,_on = 0,true
		_signals[remoteName]["_signal"..this] = function()
			val = tick()
			_on = false
		end
		repeat task.wait() until _on == false
		_signals[remoteName]["_signal"..this] = nil
		return (val-_now)
	end
	function __new:wait()
		return self:Wait()
	end
	function __new:Listen(waitTill: boolean | any, callback: any)
		if typeof(waitTill) == "boolean" and waitTill == true then
			if __disconnected then
				__disconnected = false
			end
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
		return self:Listen(waitTill, callbacks)
	end
	function __new:Once(waitTill: boolean | any, callbacks: any)
		self:Listen(waitTill, callbacks)
		if __callbacks[remoteName] then
			__callbacks[remoteName]["_once"] = true
		end
	end
	function __new:once(waitTill: boolean | any, callbacks: any)
		self:Once(waitTill, callbacks)
	end
	if __nets and __nets[remoteName]._type == "RemoteEvent" then
		function __new:Disconnect(message: string?)
			if __new and __callbacks[remoteName] ~= nil and __disconnected == false then
				if __callbacks[remoteName]["_once"] ~= nil then
					Debug.__direct_debug(__callbacks[remoteName]["_once"] == true, "[FastNet2]: Couldn't disconnect due :Once still on, try again.", 3, 2)
				end
				__callbacks[remoteName] = nil
				__disconnected = true
				if message and typeof(message) == "string" and message:len() > 0 then
					Debug.__direct_debug(message:len() <= 0, "[FastNet2]: "..message, 2)
				end
			end
		end
		function __new:disconnect(message: string?)
			self:Disconnect(message)
		end
		if IsServer then
			function __new:Fires(...: any)
				local _currentIdentifier: Tany = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				table.insert(_currentIdentifier, { "All", { ... } })
			end
			function __new:Fire(player: Player, ...: any)
				local _currentIdentifier: Tany = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				table.insert(_currentIdentifier, { player, { ... } })
			end
		else
			function __new:Fire(...: any)
				local _currentIdentifier: Tany = _toSend[remoteName]
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
	else
		if IsServer then
			function __new:Pull(player: Player, timeout: number, ...: any): any?
				Debug.__direct_debug(typeof(player) == "Instance", "[FastNet2]: Invalid type of player.", 2)
				local _currentIdentifier: Tany = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				if not _signals[remoteName] then
					_createSignal(remoteName)
				end
				if timeout and typeof(timeout) == "number" then
					if timeout < 5 then
						timeout = 5
					end
				else
					timeout = 5
				end
				local result, finish, _t, toreturn = false, false, tick(), nil
				local _makeId = _createId()
				local tosend: any = {...}
				_signals[remoteName]["_invokeSignal".._makeId] = function(...)
					toreturn = (...)
					finish = true
				end
				local _yield = task.spawn(function()
					table.insert(_currentIdentifier, {player, {_makeId, tosend}})
				end)
				while (not finish) do
					if (tick() - _t) >= timeout then
						finish = true
						task.cancel(_yield)
						break
					end
					task.wait()
				end
				_signals[remoteName]["_invokeSignal".._makeId] = nil
				return toreturn
			end
		else
			function __new:Pull(timeout: number, ...: any): any?
				local _currentIdentifier: Tany = _toSend[remoteName]
				if not _currentIdentifier then
					if IsExist(remoteName) then
						_currentIdentifier = _createIdentifier(remoteName)
					end
				end
				if not _signals[remoteName] then
					_createSignal(remoteName)
				end
				if timeout and typeof(timeout) == "number" then
					if timeout < 5 then
						timeout = 5
					end
				else
					timeout = 5
				end
				local result, finish, _t, toreturn = false, false, tick(), nil
				local _makeId = _createId()
				local tosend: any = {...}
				_signals[remoteName]["_invokeSignal".._makeId] = function(...)
					toreturn = (...)
					finish = true
				end
				local _yield = task.spawn(function()
					table.insert(_currentIdentifier, {_makeId, tosend})
				end)
				while (not finish) do
					if (tick() - _t) >= timeout then
						finish = true
						task.cancel(_yield)
						break
					end
					task.wait()
				end
				_signals[remoteName]["_invokeSignal".._makeId] = nil
				return toreturn
			end
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

function FastNet2:get(remoteName: string, waitFor: number?): Tany
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
				__nets[remoteName] = {
					_type = "RemoteFunction",
					name = remoteName
				}
				-- Debug.__direct_debug(1 ~= 1, "[FastNet2]: RemoteFunction features is currently not available.", 2)
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
		for identifier: string, v in pkg do
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
					local to_returns_invoke: any = {}
					local index_invokes: number = 0
					for index, data in v do
						if __callbacks[identifier] ~= nil then
							if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
								local _call = __callbacks[identifier]["func"](plr, table.unpack(data[2] or {}))
								table.insert(to_returns_invoke, {data[1], {_call}})
							elseif typeof(data[1]) == "table" then
								if __callbacks[identifier] ~= nil then
									Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
								end
								for index, datas in table.unpack(v) do
									if typeof(index) == "number" and typeof(datas) == "table" and _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
										Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
									end
									v[index] = nil
								end
							else
								Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
							end
							if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
								__callbacks[identifier] = nil
							end
						end
					end
					task.spawn(function()
						if #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], {plr, to_returns_invoke})
						end
						for i,_call in _signals[identifier] do
							if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
								_call()
							end
						end
					end)
				elseif -- invoke response
					_findIdentifier(identifier)
					and IsExist(identifier)
				then
					for index, datas in table.unpack(v) do
						if typeof(index) == "number" and typeof(datas) == "table" and _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
							Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
						end
					end
					task.spawn(function()
						for i,_call in _signals[identifier] do
							if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
								_call()
							end
						end
					end)
				end
			end
		end
	end)
elseif IsClient then
	_NetEvent.OnClientEvent:Connect(function(pkg)
		for identifier: string, _data in pkg do
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
					local to_returns_invoke: any = {}
					local index_invokes: number = 0
					for index, data in _data do
						if __callbacks[identifier] ~= nil then
							if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
								local _call = __callbacks[identifier]["func"](table.unpack(data[2] or {}))
								table.insert(to_returns_invoke, {data[1], {_call}})
							elseif typeof(data[1]) == "table" then
								if __callbacks[identifier] ~= nil then
									Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
								end
								for index, datas in table.unpack(_data) do
									if typeof(index) == "number" and typeof(datas) == "table" and _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
										Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
									end
								end
							else
								Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
							end
							if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
								__callbacks[identifier] = nil
							end
						end
					end
					task.spawn(function()
						if #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], to_returns_invoke)
						end
						for i,_call in _signals[identifier] do
							if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
								_call()
							end
						end
					end)
				elseif -- invoke response
					_findIdentifier(identifier)
					and IsExist(identifier)
				then
					for index, datas in table.unpack(_data) do
						if typeof(index) == "number" and typeof(datas) == "table" and _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
							Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
						else
							if not _reDo[identifier] then
								_reDo[identifier] = {}
							end
							table.insert(_reDo[identifier], _data)
						end
					end
					task.spawn(function()
						for i,_call in _signals[identifier] do
							if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
								print("call signal")
								_call()
							end
						end
					end)
				end
			end
		end
	end)
end

-- Internal Events Handler
local __t = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - __t) >= (1 / 60 - 0.00015) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		task.spawn(function()
			for identifier: string, _data in _reDo do
				if typeof(identifier) == "string" and #_data > 0 then
					_data = table.unpack(_data)
					if #_data <= 0 then
						break
					end
					if
						_findIdentifier(identifier)
						and IsExist(identifier)
						and __callbacks[identifier] ~= nil
						and __callbacks[identifier]["func"] ~= nil
					then
						local to_returns_invoke: any = {}
						local index_invokes: number = 0
						for index, data in _data do
							if __callbacks[identifier] ~= nil then
								if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
									local _call = __callbacks[identifier]["func"](table.unpack(data[2] or {}))
									table.insert(to_returns_invoke, {data[1], {_call}})
								else
									if __callbacks[identifier] ~= nil then
										Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
									else
										for index, datas in table.unpack(_data) do
											if typeof(index) == "number" and typeof(datas) == "table" and _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
												Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
											end
										end
									end
								end
								if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
									__callbacks[identifier] = nil
								end
								table.remove(_data, index)
							end
						end
						task.spawn(function()
							if #to_returns_invoke > 0 then
								table.insert(_toSend[identifier], to_returns_invoke)
							end
							for i,_call in _signals[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									_call()
								end
							end
						end)
					end
				end
			end
		end)
		
		local to_send: Tany = {
			["Server"] = {},
			["Client"] = {},
		}
		local __reach_s_max: boolean = false
		local __reach_c_max: boolean = false
		local __Sindex: number = 0
		local __Cindex: number = 0
		for identifier: string, packages in _toSend do
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
			for identifier: string, _pkgs in to_send["Server"] do
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
				for identifier: string, pkg in to_send_to_client do
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
return table.freeze(Core)