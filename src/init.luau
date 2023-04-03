--!strict

-- FastNet2 (copyright @Eternity_Devs under MIT License)
-- v0.0.8-pre-alpha (refresh)

--[[
>>> Design Order (Internal Process)
	-> Begin process "reDo" connections availables (with task.spawn for directed to next order)
	-> Begin process "onHold" connections availables (with task.spawn for directed to next order)
	-> Begin process "encoding" packets data connections availables
	-> Begin process "main connections order"
		|-> Begin process "process packing connections ordered" availables
		|-> Begin process "repack to single-pack"
		|-> Begin process "sent packed"
	-> Close and clear all cache/used tables
<<<
]]--

assert(script:IsDescendantOf(game:GetService("ReplicatedStorage")), "Please place the FastNet2 module into ReplicatedStorage.")

local __load_s: any = tick()
local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = "0.0.8"
FastNet2.build = 8

type Tany = { [any]: any }
type tHold = { [string]: Tany}

--// Settings
local _enableLimitingRate: boolean = false -- default: true, off it if want pure or for benchmarking
local _maxRate_perEvent: number = 500 -- default: 500
local __threads: number = 50  -- default: 50
local __currentMode: number = 2
local _enableEncoding: boolean = false -- default: false, encode to binary (*for string and numbers only*) & turning this feature may risk bandwidth usages taken and performances
local smooth_mode: number =  2-- default: 2, Modes: 1 (Low 30), 2 (Normal 60), 3 (High 90), 4 (Ultra 120)
local useb64: boolean = false -- default: false, if it false it will use binary instead else base64 for encode
local waitPlr: boolean = false -- default: false, hold connection until player character is loaded/spawn, off it for Deferred which is still experimental/beta

if typeof(_enableLimitingRate) ~= "boolean" then
	_enableLimitingRate = true
end
if typeof(_enableEncoding) ~= "boolean" then
	_enableEncoding = false
end
if typeof(useb64) ~= "boolean" then
	useb64 = false
end

if smooth_mode == 1 then
	smooth_mode = (1 / 30 - 0.00015)
elseif smooth_mode == 2 then
	smooth_mode = (1 / 60 - 0.00015)
elseif smooth_mode == 3 then
	smooth_mode = (1 / 90 - 0.00015)
elseif smooth_mode == 4 then
	smooth_mode = (1 / 120 - 0.00015)
else
	smooth_mode = (1 / 60 - 0.00015) -- to normal
end

if _maxRate_perEvent ~= nil then
	if _maxRate_perEvent < 1 or _maxRate_perEvent >= math.huge then
		_maxRate_perEvent = 500
	end
else
	_maxRate_perEvent = 500
end

-- FastNet2 Warehouse & Middleware
local __callbacks: Tany = {}
local __nets: Tany = {}
local _toSend: Tany = {}
local _signals: any = {}
local _reDo: any = {}
local _onHold: tHold = {}

local initialized = false

local LevelModes: Tany = {
	[1] = "Low",
	[2] = "Default",
	[3] = "High",
}

if __threads < 25 or __threads > 100 then
	__threads = 25
end

--// Services
local StatsService = game:GetService("Stats")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

--// Load Utils
local Debug: any = require(script:WaitForChild("Debug"))
local Threads: any = require(script:WaitForChild("Thread"))
local Driver: any = require(script:WaitForChild("Driver"))

if _enableEncoding then
	Debug.__direct_debug(_enableEncoding == true, "[FastNet2]: Encode is enabled.", 2)
end

local Nets: any
local _NetEvent: RemoteEvent
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

if IsClient then
	Debug.set_debug(false)
end

local PlayerStatus: Tany = {} -- players status for holding connection feature method (experimental)
if IsServer and waitPlr then
	Players.PlayerAdded:Connect(function(player)
		if player then
			if not PlayerStatus[player.Name] then
				PlayerStatus[player.Name] = false
			end
			player.CharacterAdded:Connect(function(character)
				if character and character:IsDescendantOf(game:GetService("Workspace")) and character:FindFirstChild("Humanoid") then
					PlayerStatus[player.Name] = true
				else
					task.wait(2.5) -- wait for recheck
					if character and character:IsDescendantOf(game:GetService("Workspace")) and character:FindFirstChild("Humanoid") then
						PlayerStatus[player.Name] = true
					else
						PlayerStatus[player.Name] = false
					end
				end
			end)
			player.CharacterRemoving:Connect(function(character)
				if character and character:IsDescendantOf(game:GetService("Workspace")) and character:FindFirstChild("Humanoid") and character:FindFirstChild("Humanoid").Health > 0 then
					PlayerStatus[player.Name] = true
				else
					PlayerStatus[player.Name] = false
				end
			end)
			if player and player.Character and player.Character:IsDescendantOf(game:GetService("Workspace")) and player.Character:FindFirstChild("Humanoid") then
				PlayerStatus[player.Name] = true
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if player and PlayerStatus[player.Name] ~= nil then
			PlayerStatus[player.Name] = nil
		end
	end)
	Debug.__direct_debug(1 ~= 1, "[FastNet2]: Hold connection enabled (beta/experimental).", 1)
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
		if __currentMode == 3 then
			__threads = 100
		elseif __currentMode == 2 then
			__threads = 50
		else
			__threads = 25
		end
		Threads = Threads.__start(__threads)
	end
	if __threads < 25 or __threads > 100 then
		__threads = 25
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

function randNum(min: number, max:number, new: boolean | nil): number
	if new then
		return Random.new():NextInteger(min, max)
	end
	return randNum(min, max)
end

function _createId(length: number | nil): string -- faster than UUID
	if length ~= nil and tonumber(length) == nil then
		return table.concat({randNum(11,999), string.char(randNum(97, 122)), string.char(randNum(97, 122)), string.char(randNum(97, 122)), randNum(11,999), string.char(randNum(97, 122)), string.char(randNum(97, 122)), randNum(11,65535), string.char(randNum(97, 122)), randNum(1,65535)})
	end
	if length == nil or length < 5 or length > 16 then
		return table.concat({randNum(11,999), string.char(randNum(97, 122)), string.char(randNum(97, 122)), string.char(randNum(97, 122)), randNum(11,999), string.char(randNum(97, 122)), string.char(randNum(97, 122)), randNum(11,65535), string.char(randNum(97, 122)), randNum(1,65535)})
	else
		local _rand: Tany = {}
		for i=1,length do
			if randNum(1, 4) == 4 then
				table.insert(_rand, randNum(11,999))
			elseif randNum(1, 2) == 2 then
				table.insert(_rand, randNum(1,99))
			else
				table.insert(_rand, string.char(randNum(97, 122)))
			end
		end
		return table.concat(_rand)
	end
end

-- Identifier
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
--function Core.init(enableDebugs: boolean, levelForPrimaryModeThreads: number?): any
--	Debug.__direct_debug(typeof(enableDebugs) == "boolean", "[FastNet2]: Invalid type of debug option", 2)
--	if levelForPrimaryModeThreads ~= nil then
--		Debug.__direct_debug(typeof(levelForPrimaryModeThreads) == "number", "[FastNet2]: Invalid type of level mode", 2)
--	end
--	Debug.set_debug(enableDebugs or true)
--	reConfigure(levelForPrimaryModeThreads)
--	return table.freeze(FastNet2)
--end

function FastNet2._setdebug(On: boolean)
	Debug.__direct_debug(typeof(On) == "boolean", "[FastNet2]: Invalid type of debug option", 2)
	Debug.set_debug(On or true)
end

function FastNet2.getdebugcache(maxrange: number): Tany
	return Debug.get_debugs_inrange(maxrange or 100)
end

function FastNet2.CreateUUID(): string
	return Driver.CreateUUID()
end

function FastNet2.randStr(length: number | nil): string
	return _createId(length)
end

function FastNet2.randNum(min: number, max: number, NewInt: boolean | nil): number
	return randNum(min, max, NewInt)
end

function FastNet2.toBestFormNum(num: number): number | string
	return Driver.toBestFormNum(num)
end

function FastNet2.Nearest(player: Player, radiusDist: any, customCharacter: boolean?): {Player}
	return Driver.Nearest(player, radiusDist, customCharacter)
end

function FastNet2.Wait(): number
	--[[
	Somereason just use PostSimulator as Heartbeat because Heartbeat only fire after Render Signal fire here why if the server/client dropped frame
	could be bad, PostSimulator is the new of Heartbeat, PostSimultion dont need to wait until Render Signal fired.
	PostSimulation is 1/60 or print(RunService.PostSimulation:Wait())
	]]--
	return RunService.PostSimulation:Wait() -- 60 frame / 0.0166s / 16.66ms
end
function FastNet2.wait(): number
	return FastNet2.Wait()
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
		local finish, _t = false, tick()
		local _yield = task.spawn(function()
			repeat
				finish = IsExist(remoteName)
				task.wait()
			until finish == true
			finish = true
		end)
		while (not finish) do
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
	function __new:Wait(): number -- EXPERIMENTAL
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
	function __new:wait(): number
		return self:Wait()
	end
	function __new:Listen(waitTill: boolean | any, callback: any): Tany
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
		if not table.isfrozen(self) then
			return table.freeze(self)
		else
			return self
		end
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
	if __nets and __nets[remoteName] and __nets[remoteName]._type == "re" then
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
				if not _toSend[remoteName] then
					if IsExist(remoteName) then
						_createIdentifier(remoteName)
					else
						return
					end
				end
				--local _currentIdentifier: Tany = _toSend[remoteName]
				--if not _currentIdentifier then
				--	if IsExist(remoteName) then
				--		_currentIdentifier = _createIdentifier(remoteName)
				--	end
				--end
				if _enableLimitingRate then -- rate limit for client only
					if #_toSend[remoteName] > (_maxRate_perEvent or 500) then
						return -- reject
					end
				end
				table.insert(_toSend[remoteName], { ... })
			end
		end
		function __new:Disconnected(): boolean
			return __disconnected
		end
		function __new:disconnected(): boolean
			return self:Disconnected()
		end
	elseif __nets and __nets[remoteName] and __nets[remoteName]._type == "rf" then
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
				local finish, _t, toreturn = false, tick(), nil
				local _makeId = _createId()
				local tosend: any = {...}
				_signals[remoteName]["_invokeSignal".._makeId] = function(...)
					finish = true
					toreturn = (...)
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
			function __new:pull(player: Player, timeout: number, ...: any): any?
				return self:Pull(player, timeout, ...)
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
				local finish, _t, toreturn = false, tick(), nil
				local _makeId = _createId()
				local tosend: any = {...}
				_signals[remoteName]["_invokeSignal".._makeId] = function(...)
					finish = true
					toreturn = (...)
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
			function __new:pull(player: Player, timeout: number, ...: any): any?
				return self:Pull(player, timeout, ...)
			end
		end
	else
		table.clear(__new)
		task.spawn(function()
			if __nets and __nets[remoteName] then
				Debug.__direct_debug(1 ~= 1, string.format("[FastNet2]: CRITICAL -> %s corrupted?", remoteName), 3)
			else
				Debug.__direct_debug(1 ~= 1, "[FastNet2]: CRITICAL -> Unknown error", 2)
			end
		end)
		return table.freeze({})
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
			if typeRemote == "event"
				or typeRemote == "events"
				or typeRemote == "remoteevent"
				or typeRemote == "remoteevents"
				or typeRemote == "re"
				or typeRemote == "remote"
				or typeRemote == "remotes" then
				__nets[remoteName] = {
					_type = "re",
					name = remoteName,
				}
			elseif
				typeRemote == "invoke"
				or typeRemote == "invokes"
				or typeRemote == "function"
				or typeRemote == "functions"
				or typeRemote == "remotefunction"
				or typeRemote == "remotefunctions"
				or typeRemote == "rf"
			then
				__nets[remoteName] = {
					_type = "rf",
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

debug.setmemorycategory("FastNet2")
if IsServer then
	_NetEvent.OnServerEvent:Connect(function(plr, pkg)
		if pkg and typeof(pkg) == "table" then
			debug.profilebegin("FastNet2.server")
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
						local to_returns_invoke: any = {} -- middleware
						local index_invokes: number = 0
						for index, data in v do
							if __callbacks[identifier] ~= nil then
								if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
									local _call = __callbacks[identifier]["func"](plr, table.unpack(data[2] or {}))
									table.insert(to_returns_invoke, {data[1], {_call}})
								elseif typeof(data[1]) == "table" then
									-- if plr and waitPlr and PlayerStatus[plr.Name] == true then
									-- 	if __callbacks[identifier] ~= nil then
									-- 		if _enableEncoding then
									-- 			if typeof(data) == "table" then
									-- 				for indexs, to_encode in data do
									-- 					data[indexs] = Driver.dec(useb64 or false, to_encode)
									-- 				end
									-- 			end
									-- 		end
									-- 		Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									-- 	end
									-- elseif plr and waitPlr then
									-- 	table.insert(_onHold[plr.Name], data)
									-- elseif not waitPlr then
									-- 	if __callbacks[identifier] ~= nil then
									-- 		if _enableEncoding then
									-- 			if typeof(data) == "table" then
									-- 				for indexs, to_encode in data do
									-- 					data[indexs] = Driver.dec(useb64 or false, to_encode)
									-- 				end
									-- 			end
									-- 		end
									-- 		Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									-- 	end
									-- end
									if __callbacks[identifier] ~= nil and _enableEncoding then
										if typeof(data) == "table" then
											for indexs, to_encode in data do
												data[indexs] = Driver.dec(useb64 or false, to_encode)
											end
										end
										Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									end
									for _index, datas in table.unpack(v) do
										if typeof(_index) == "number" and typeof(datas) == "table" and datas[1] ~= nil then
											if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
												if _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
													Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
												end
											elseif plr and identifier ~= nil and __callbacks[identifier] ~= nil and __callbacks[identifier]["func"] ~= nil then
												if _enableEncoding then
													if typeof(datas) == "table" then
														for indexs, to_encode in datas do
															datas[indexs] = Driver.dec(useb64 or false, to_encode)
														end
													end
												end
												Threads(__callbacks[identifier]["func"], plr, table.unpack(datas or {}))
											else
												v[_index] = nil
											end
										elseif plr and identifier ~= nil and __callbacks[identifier] ~= nil and __callbacks[identifier]["func"] ~= nil and datas ~= nil then
											local _cb = {datas}
											if _enableEncoding then
												for indexs, to_encode in _cb do
													if typeof(to_encode) == "table" then
														for _i,x in to_encode do
															_cb[indexs][_i] = Driver.dec(useb64 or false, x)
														end
													else
														_cb[indexs] = Driver.dec(useb64 or false, to_encode)
													end
												end
											end
											Threads(__callbacks[identifier]["func"], plr, table.unpack(_cb or {}))
										else
											v[_index] = nil
										end
									end
								else
									-- if __callbacks[identifier] ~= nil then
									-- 	if plr and waitPlr and PlayerStatus[plr.Name] == true then
									-- 		if _enableEncoding then
									-- 			if typeof(data) == "table" then
									-- 				for indexs, to_encode in data do
									-- 					data[indexs] = Driver.dec(useb64 or false, to_encode)
									-- 				end
									-- 			end
									-- 		end
									-- 		Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									-- 	elseif plr and waitPlr then
									-- 		table.insert(_onHold[plr.Name], data)
									-- 	elseif not waitPlr then
									-- 		if _enableEncoding then
									-- 			if typeof(data) == "table" then
									-- 				for indexs, to_encode in data do
									-- 					data[indexs] = Driver.dec(useb64 or false, to_encode)
									-- 				end
									-- 			end
									-- 		end
									-- 		Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									-- 	end
									-- end
									if __callbacks[identifier] ~= nil and _enableEncoding then
										if typeof(data) == "table" then
											for indexs, to_encode in data do
												data[indexs] = Driver.dec(useb64 or false, to_encode)
											end
										end
										Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									end
								end
								if __callbacks[identifier]["_once"] ~= nil and __callbacks[identifier]["_once"] == true then
									__callbacks[identifier] = nil
								end
							end
						end
						if #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], {plr, to_returns_invoke})
							table.clear(to_returns_invoke) -- prevent memory leaks?
						end
						task.spawn(function()
							debug.profilebegin("signal")
							for i,_call in _signals[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									_call()
								end
							end
							debug.profileend()
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
							debug.profilebegin("signal")
							for i,_call in _signals[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									_call()
								end
							end
							debug.profileend()
						end)
					end
				end
			end
			debug.profileend()
			table.clear(pkg) -- prevent memory leaks?
		end
	end)
elseif IsClient then
	_NetEvent.OnClientEvent:Connect(function(pkg)
		if pkg and typeof(pkg) == "table" then
			debug.profilebegin("FastNet2.client")
			for identifier: string, _data in pkg do
				if typeof(identifier) == "string" and typeof(_data) == "table" and #_data > 0 then
					if
						_findIdentifier(identifier)
						and IsExist(identifier)
						and __callbacks[identifier] ~= nil
						and __callbacks[identifier]["func"] ~= nil
					then
						local to_returns_invoke: any = {} -- middleware
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
									for _index, datas in table.unpack(_data) do
										if typeof(_index) == "number" and typeof(datas) == "table" and datas[1] ~= nil then
											if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
												if _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
													Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
												else
													if not _reDo[identifier] then
														_reDo[identifier] = {}
													end
													table.insert(_reDo[identifier], _data)
												end
											end
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
						if #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], to_returns_invoke)
							table.clear(to_returns_invoke) -- prevent memory leaks?
						end
						task.spawn(function()
							debug.profilebegin("signal")
							for i,_call in _signals[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									_call()
								end
							end
							debug.profileend()
						end)
					elseif -- invoke response
						_findIdentifier(identifier)
						and IsExist(identifier)
					then
						for index, datas in table.unpack(_data) do
							if typeof(index) == "number" and typeof(datas) == "table" and datas[1] ~= nil then
								if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
									if _signals[identifier] ~= nil and _signals[identifier]["_invokeSignal"..datas[1]] ~= nil then
										Threads(_signals[identifier]["_invokeSignal"..datas[1]], table.unpack(datas[2] or {}))
									else
										if not _reDo[identifier] then
											_reDo[identifier] = {}
										end
										table.insert(_reDo[identifier], _data)
									end
								end
							end
						end
						task.spawn(function()
							debug.profilebegin("signal")
							for i,_call in _signals[identifier] do
								if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
									_call()
								end
							end
							debug.profileend()
						end)
					end
				end
			end
			debug.profileend()
			table.clear(pkg) -- prevent memory leaks?
		end
	end)
end

-- Internal Events Handler
local __t = os.clock()
RunService.PostSimulation:Connect(function()
	if (os.clock() - __t) >= smooth_mode or (1 / 60 - 0.00015) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		debug.profilebegin("FastNet2.Internal.process")
		task.spawn(function()
			debug.profilebegin("redo")
			if IsClient then
				for identifier: string, _data in _reDo do
					if typeof(identifier) == "string" and typeof(_data) == "table" and #_data > 0 then
						_data = table.unpack(_data)
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
			end
			debug.profileend()
		end)
		task.spawn(function()
			if IsServer and waitPlr then
				debug.profilebegin("hold")
				for player: string, data in _onHold do
					if #data == 0 then
						continue
					end
					for identifier: string, datas in data do
						if #datas > 0 then
							for index: number, _data in datas do
								if
									_findIdentifier(identifier)
									and IsExist(identifier)
								then
									if player and Players[player] then
										if waitPlr and PlayerStatus[player] == true then
											_NetEvent:FireClient(Players[player], {[identifier] = _data})
										elseif not waitPlr then
											_NetEvent:FireClient(Players[player], {[identifier] = _data})
										end
									end
									table.remove(datas, index)
								end
							end
						end
					end
				end
				debug.profileend()
			end
		end)
		-- Encoder
		if IsClient and _enableEncoding then
			debug.profilebegin("encode")
			for identifier: string, packages in _toSend do
				if typeof(packages) == "table" and #packages > 0 then
					local encoded = packages
					for i,datas in encoded do
						if not _toSend[identifier] then break end
						if typeof(datas) == "table" then
							for index, _d in datas do
								encoded[i][index] = Driver.enc(useb64 or false, _d)
							end
						end
					end
					if _toSend[identifier] then
						_toSend[identifier] = encoded
					end
				end
			end
			debug.profileend()
		end
		local to_send: Tany = {
			["Server"] = {},
			["Client"] = {},
		} -- middleware
		local __reach_s_max: boolean = false
		local __reach_c_max: boolean = false
		local __Sindex: number = 0
		local __Cindex: number = 0
		debug.profilebegin("process")
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
					if IsExist(identifier) and not to_send["Client"][identifier] then
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
					if IsExist(identifier) and not to_send["Server"][identifier] then
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
				if identifier and _pkgs then
					for index, data in _pkgs do
						if not to_send["Server"][identifier] then continue end
						if index and data then
							if typeof(data[1]) == "Instance" then
								if not to_send_to_client[identifier] then
									to_send_to_client[identifier] = {}
									to_send_to_client[identifier][data[1]] = {}
								end
								if to_send_to_client[identifier] and to_send_to_client[identifier][data[1]] then
									table.insert(to_send_to_client[identifier][data[1]], data[2])
									to_send_indexs += 1
								end
							else
								if not to_send_all_clients[identifier] then
									to_send_all_clients[identifier] = {}
								end
								table.insert(to_send_all_clients[identifier], data[2])
								to_send_all_indexs += 1
							end
						end
					end
				end
			end
			if to_send_all_indexs > 0 then
				_NetEvent:FireAllClients(to_send_all_clients)
				table.clear(to_send_all_clients)
			end
			if to_send_indexs > 0 then
				for identifier: string, pkg in to_send_to_client do
					if identifier and pkg then
						for player, _data in pkg do
							if not to_send_to_client[identifier] then continue end
							if player and _data then
								-- local _convert = {}
								-- _convert[identifier] = _data
								if player and waitPlr and PlayerStatus[player.Name] == true then
									_NetEvent:FireClient(player, {[identifier] = _data})
								elseif not waitPlr then
									_NetEvent:FireClient(player, {[identifier] = _data})
								else
									if not _onHold[player.Name] then
										_onHold[player.Name] = {}
									end
									if _onHold[player.Name] and not _onHold[player.Name][identifier] then
										_onHold[player.Name][identifier] = {}
									end
									if _onHold[player.Name] and _onHold[player.Name][identifier] then
										table.insert(_onHold[player.Name][identifier], _data)
									end
								end
							end
						end
					end
				end
				table.clear(to_send_to_client)
			end
		elseif IsClient and __Cindex > 0 then
			_NetEvent:FireServer(to_send["Client"])
		end
		debug.profileend()
		table.clear(to_send) -- prevent memory leaks?
		__t = os.clock()
		debug.profileend()
	end
end)

reConfigure(__currentMode or 2)
Debug.__direct_debug(1 ~= 1, string.format("FastNet2 initialized [ver_%s (%s) | %s | %sms]", FastNet2.version, tostring(FastNet2.build), __getProvider(), (tick() - __load_s)*1000), 2)

return table.freeze(FastNet2)
