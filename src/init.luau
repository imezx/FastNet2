--!strict

-- FastNet2 (copyright @Eternity_Devs under MIT License)
-- v0.0.8-pre-alpha (refresh)
--[[
>>> Design Order (Internal Process)
	-> Begin process "reDo" connections availables (with task.spawn for directed to next order)
	-> Begin process "onHold" connections availables (with task.spawn for directed to next order)
	-> Begin process "main connections order"
		|-> Begin process "process packing connections ordered" availables
			|-> Begin process "encoding" packets data identifier
		|-> Begin process "repack to single-packed"
		|-> Sent
	-> Clear all cache/used tables & Finish
<<<
]]
--

assert(
	script:IsDescendantOf(game:GetService("ReplicatedStorage")),
	"Please place the FastNet2 module into ReplicatedStorage."
)

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = "0.0.8"
FastNet2.build = 8.4
FastNet2.production = "Dev"
-- Internal Settings
FastNet2.Settings = {
	["CHECK_VERSION"] = true, -- default: true, check current and latest version available >> (SERVER-SIDE ONLY!) <<
	["_enableLimitingRate"] = false, -- default: true, off it if want pure or for benchmarking
	["_maxRate_perEvent"] = 500, -- default: 500
	["__threads"] = 50, -- default: 50
	["__currentMode"] = 2, -- default: 2 (1-3)
	["_enableEncoding"] = false, -- default: false, encode to binary (*for string and numbers only*) & turning this feature may risk bandwidth usages taken and performances
	["smooth_mode"] = 2, -- default: 2, Modes: 1 (Low 30), 2 (Default 60), 3 (High 90), 4 (Ultra 120) [LOCK-FRAME, NOT REALLY AFFECT TO PERFORMANCE]
	["useb64"] = false, -- default: false, if it false it will use binary instead else base64 for encode
	["waitPlr"] = false, -- default: false, hold connection until player character is loaded/spawn, off it for Deferred which is still experimental/beta
	["SILENT_DEBUG"] = false, -- default: false, set debug logs being silent [NOT AFFECT TO CLIENT]
}

local __load_s: any = tick()

if typeof(FastNet2.Settings.SILENT_DEBUG) ~= "boolean" then
	FastNet2.Settings.SILENT_DEBUG = false
end
if typeof(FastNet2.Settings._enableLimitingRate) ~= "boolean" then
	FastNet2.Settings._enableLimitingRate = true
end
if typeof(FastNet2.Settings._enableEncoding) ~= "boolean" then
	FastNet2.Settings._enableEncoding = false
end
if typeof(FastNet2.Settings.useb64) ~= "boolean" then
	FastNet2.Settings.useb64 = false
end

if FastNet2.Settings.smooth_mode == 1 then
	FastNet2.Settings.smooth_mode = (1 / 30 - 0.00015)
elseif FastNet2.Settings.smooth_mode == 2 then
	FastNet2.Settings.smooth_mode = (1 / 60 - 0.00015)
elseif FastNet2.Settings.smooth_mode == 3 then
	FastNet2.Settings.smooth_mode = (1 / 90 - 0.00015)
elseif FastNet2.Settings.smooth_mode == 4 then
	FastNet2.Settings.smooth_mode = (1 / 120 - 0.00015)
else
	FastNet2.Settings.smooth_mode = (1 / 60 - 0.00015) -- to normal
end

if FastNet2.Settings._maxRate_perEvent ~= nil then
	if FastNet2.Settings._maxRate_perEvent < 1 or FastNet2.Settings._maxRate_perEvent >= math.huge then
		FastNet2.Settings._maxRate_perEvent = 500
	end
else
	FastNet2.Settings._maxRate_perEvent = 500
end

type Tany = { [any]: any }
type tHold = { [string]: Tany }

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

if FastNet2.Settings.__threads < 25 or FastNet2.Settings.__threads > 100 then
	FastNet2.Settings.__threads = 25
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

local PlayerStatus: Tany = {} -- players status for holding connection feature method (experimental)
function _loadPlrStatus(player)
	if player then
		if not PlayerStatus[player.Name] then
			PlayerStatus[player.Name] = false
		end
		player.CharacterAdded:Connect(function(character)
			if
				player
				and character
				and character:IsDescendantOf(game:GetService("Workspace"))
				and character:FindFirstChild("Humanoid")
			then
				PlayerStatus[player.Name] = true
			elseif player then
				task.wait(2.5) -- wait for recheck
				if
					player
					and character
					and character:IsDescendantOf(game:GetService("Workspace"))
					and character:FindFirstChild("Humanoid")
				then
					PlayerStatus[player.Name] = true
				elseif player then
					PlayerStatus[player.Name] = false
				end
			end
			character:WaitForChild("Humanoid").Died:Connect(function()
				if
					player
					and character
					and character:IsDescendantOf(game:GetService("Workspace"))
					and character:FindFirstChild("Humanoid")
					and character:FindFirstChild("Humanoid").Health > 0
				then
					PlayerStatus[player.Name] = true
				elseif player then
					PlayerStatus[player.Name] = false
				end
			end)
		end)
		player.CharacterRemoving:Connect(function(character)
			if
				player
				and character
				and character:IsDescendantOf(game:GetService("Workspace"))
				and character:FindFirstChild("Humanoid")
				and character:FindFirstChild("Humanoid").Health > 0
			then
				PlayerStatus[player.Name] = true
			elseif player then
				PlayerStatus[player.Name] = false
			end
		end)
		if
			player
			and player.Character
			and player.Character:IsDescendantOf(game:GetService("Workspace"))
			and player.Character:FindFirstChild("Humanoid")
		then
			PlayerStatus[player.Name] = true
			player.Character:WaitForChild("Humanoid").Died:Connect(function()
				if
					player
					and player.Character
					and player.Character:IsDescendantOf(game:GetService("Workspace"))
					and player.Character:FindFirstChild("Humanoid")
					and player.Character:FindFirstChild("Humanoid").Health > 0
				then
					PlayerStatus[player.Name] = true
				elseif player then
					PlayerStatus[player.Name] = false
				end
			end)
		end
	end
end

if IsServer and FastNet2.Settings.waitPlr then
	Players.PlayerAdded:Connect(_loadPlrStatus)
	Players.PlayerRemoving:Connect(function(player)
		if player and PlayerStatus[player.Name] ~= nil then
			PlayerStatus[player.Name] = nil
		end
	end)
	Debug.__direct_debug(1 ~= 1, "[FastNet2]: Hold connection enabled (beta/experimental).", 1)
end

if IsClient then
	Debug.silentDebug(false)
else
	if FastNet2.Settings.SILENT_DEBUG == true then
		Debug.silentDebug(true)
	end
end
if FastNet2.Settings._enableEncoding then
	Debug.__direct_debug(FastNet2.Settings._enableEncoding == true, "[FastNet2]: Encode is enabled.", 2)
end

local _NetEvent: RemoteEvent
if IsServer then
	if not script:FindFirstChild("Event") then
		_NetEvent = Instance.new("RemoteEvent", script)
		_NetEvent.Name = "Event"
	else
		_NetEvent = script:WaitForChild("Event")
	end
else
	if not script:FindFirstChild("Event") then
		repeat task.wait() until script:FindFirstChild("Event")
	end
	_NetEvent = script:WaitForChild("Event")
end

--// Internal Functions
function reConfigure(): string -- EXPERIMENTAL FEATURE
	Debug.__direct_debug(
		initialized == false,
		"[FastNet2]: couldn't re-configure internal system settings [Already set].",
		2
	)
	if not initialized then
		initialized = true
		if not LevelModes[FastNet2.Settings.__currentMode] then
			FastNet2.Settings.__currentMode = 2
		end
		if FastNet2.Settings.__currentMode == 3 then
			FastNet2.Settings.__threads = 100
		elseif FastNet2.Settings.__currentMode == 2 then
			FastNet2.Settings.__threads = 50
		else
			FastNet2.Settings.__threads = 25
		end
		Threads = Threads.__start(FastNet2.Settings.__threads)
	end
	if FastNet2.Settings.__threads < 25 or FastNet2.Settings.__threads > 100 then
		FastNet2.Settings.__threads = 25
	end
	task.spawn(function()
		if FastNet2.Settings.CHECK_VERSION and IsServer then
			local HttpService = game:GetService("HttpService")
			local success, ver = pcall(function()
				return tonumber(HttpService:GetAsync("https://raw.githubusercontent.com/imezx/FastNet2/master/VERSION", true))
			end)
			if success then
				Debug.__direct_debug(
					FastNet2.build >= ver,
					string.format(
						"[FastNet2]: New version available (new: %s | current: %s)",
						tostring(ver),
						tostring(FastNet2.build)
					),
					1
				)
			else
				Debug.__direct_debug(success, string.format("[FastNet2]: Failed to check latest version (:%s)", tostring(ver)), 2)
			end
		end
	end)
	return LevelModes[FastNet2.Settings.__currentMode]
end
function __getProvider(toBool: boolean?): any
	if typeof(toBool) == "boolean" and toBool == true then
		return { IsServer, IsClient }
	end
	return IsClient and "Client" or "Server"
end

function IsExist(remoteName: string): boolean
	return __nets[remoteName] and true or false
end

function randNum(min: number, max: number, new: boolean?): number
	if new then
		return Random.new():NextInteger(min, max)
	end
	return math.random(min, max)
end

function _createId(length: number | nil): string | number
	if length ~= nil and tonumber(length) == nil then
		return table.concat({
			randNum(11, 999, true),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			randNum(11, 999, true),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			randNum(11, 65535, true),
			string.char(randNum(97, 122, true)),
			randNum(1, 65535, true),
		})
	end
	if length == nil or length < 5 or length > 16 then
		return table.concat({
			randNum(11, 999, true),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			randNum(11, 999, true),
			string.char(randNum(97, 122, true)),
			string.char(randNum(97, 122, true)),
			randNum(11, 65535, true),
			string.char(randNum(97, 122, true)),
			randNum(1, 65535, true),
		})
	else
		local _rand: Tany = {}
		for i = 1, length do
			if randNum(1, 4, true) == 4 then
				table.insert(_rand, randNum(11, 999, true))
			elseif randNum(1, 2, true) == 2 then
				table.insert(_rand, randNum(1, 99, true))
			else
				table.insert(_rand, string.char(randNum(97, 122, true)))
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
	Debug.__direct_debug(
		__nets[remoteName] ~= nil,
		"[FastNet2]: Couldn't create signal, Spesific remote not exists.",
		2,
		nil,
		Driver.dec(FastNet2.Settings.useb64 or false, remoteName)
	)
	if __nets[remoteName] and _signals[remoteName] == nil then
		_signals[remoteName] = {}
	end
end

-- FastNet2 Remote (APIs Function) for Server-Side
local Server = {}
Server.__index = Server

type Server = Server

function Server.new(remoteName, _type)
	local self = setmetatable({}, Server)
	self.remoteName = remoteName
	self._type = _type
	self.__disconnected = false
	return self
end

function Server.Fires(self: Server, ...: any)
	local _currentIdentifier: Tany = _toSend[self.remoteName]
	if IsExist(self.remoteName) and _currentIdentifier then
		table.insert(_currentIdentifier, { "All", { ... } })
	end
end
function Server.fires(self: Server, ...: any)
	return self.Fires(self, ...)
end
function Server.Fire(self: Server, player: Player, ...: any)
	local _currentIdentifier: Tany = _toSend[self.remoteName]
	if IsExist(self.remoteName) and _currentIdentifier then
		table.insert(_currentIdentifier, { player, { ... } })
	end
end
function Server.fire(self: Server, player: Player, ...: any)
	return self.Fire(self, player, ...)
end
function Server.Pull(self: Server, player: Player, timeout: number, ...: any): any?
	Debug.__direct_debug(typeof(player) == "Instance", "[FastNet2]: Invalid type of player.", 2, nil, Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName))
	local _currentIdentifier: Tany = _toSend[self.remoteName]
	if IsExist(self.remoteName) and _currentIdentifier then
		if not _signals[self.remoteName] then
			_createSignal(self.remoteName)
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
		local tosend: any = { ... }
		_signals[self.remoteName]["_invokeSignal" .. _makeId] = function(...)
			finish = true
			toreturn = (...)
		end
		local _yield = task.spawn(function()
			table.insert(_currentIdentifier, { player, { _makeId, tosend } })
		end)
		while not finish do
			if (tick() - _t) >= timeout then
				finish = true
				task.cancel(_yield)
				break
			end
			task.wait()
		end
		_signals[self.remoteName]["_invokeSignal" .. _makeId] = nil
		return toreturn
	end
	return nil
end
function Server.pull(self: Server, player: Player, timeout: number, ...: any): any?
	return self.Pull(self, player, timeout, ...)
end
function Server.Wait(self: Server): number -- EXPERIMENTAL
	local _now, this = os.clock(), _createId()
	local val, _on = 0, true
	_signals[self.remoteName]["_signal" .. this] = function()
		val = os.clock()
		_on = false
		_signals[self.remoteName]["_signal" .. this] = nil
	end
	repeat
		task.wait()
	until _on == false and _findIdentifier(self.remoteName)
	return (val - _now)
end
function Server.wait(self: Server): number
	return self.Wait(self)
end
function Server.Listen(self: Server, waitTill: boolean | any, callback: any): Tany
	if typeof(waitTill) == "boolean" and waitTill == true then
		if self.__disconnected then
			self.__disconnected = false
		end
		repeat
			task.wait()
		until self.__disconnected == false and IsExist(self.remoteName) == true
		__callbacks[self.remoteName] = {
			func = callback or nil,
		}
	else
		__callbacks[self.remoteName] = {
			func = waitTill or nil,
		}
	end
	__callbacks[self.remoteName]["_type"] = __nets[self.remoteName]._type
	if not table.isfrozen(self) then
		return table.freeze(self)
	else
		return self
	end
end
function Server.listen(self: Server, waitTill: boolean | any, callback: any): Tany
	return self.Listen(self, waitTill, callback)
end
function Server.Once(self: Server, waitTill: boolean | any, callbacks: any)
	self:Listen(waitTill, callbacks)
	if __callbacks[self.remoteName] then
		__callbacks[self.remoteName]["_once"] = true
	end
end
function Server.once(self: Server, waitTill: boolean | any, callbacks: any)
	self.Once(self, waitTill, callbacks)
end
function Server.Disconnect(self: Server, message: string?)
	if self and self.__disconnected == false then
		self.__disconnected = true
		__callbacks[self.remoteName] = nil
		if message and typeof(message) == "string" and message:len() > 0 then
			Debug.__direct_debug(message:len() <= 0, "[FastNet2]: " .. message, 2)
		end
	elseif self then
		Debug.__direct_debug(1 ~= 1, string.format("[FastNet2]: Unable to disconnect -> %s", Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName)), 2, nil, Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName))
	end
end
function Server.disconnect(self: Server, message: string?)
	self.Disconnect(self, message)
end
function Server.Disconnected(self: Server): boolean
	return self.__disconnected
end
function Server.disconnected(self: Server): boolean
	return self.Disconnected(self)
end
function Server.logs(self: Server)
	return Debug.get_log(Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName))
end
function Server.Destroy(self: Server)
	if self and __nets[self.remoteName] ~= nil then
		__nets[self.remoteName] = nil
		__callbacks[self.remoteName] = nil
		_signals[self.remoteName] = nil
		self.__disconnected = true
		_removeIdentifier(self.remoteName)
	end
end
function Server.destroy(self: Server)
	self.Destroy(self)
end

-- FastNet2 Remote (APIs Function) for Client-Side
local Client = {}
Client.__index = Client

type Client = Client

function Client.new(remoteName, _type)
	local self = setmetatable({}, Client)
	self.remoteName = remoteName
	self._type = _type
	self.__disconnected = false
	return self
end

function Client.Fire(self: Client, ...: any)
	local _currentIdentifier: Tany = _toSend[self.remoteName]
	if IsExist(self.remoteName) and _currentIdentifier then
		if
			FastNet2.Settings._enableLimitingRate
			and #_currentIdentifier > (FastNet2.Settings._maxRate_perEvent or 500)
		then -- rate limit for client only
			return -- reject
		end
		table.insert(_currentIdentifier, { ... })
	end
end
function Client.fire(self: Client, ...: any)
	self.Fire(self, ...)
end
function Client.Pull(self: Client, timeout: number, ...: any): any?
	local _currentIdentifier: Tany = _toSend[self.remoteName]
	if IsExist(self.remoteName) and _currentIdentifier then
		if not _signals[self.remoteName] then
			_createSignal(self.remoteName)
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
		local tosend: any = { ... }
		_signals[self.remoteName]["_invokeSignal" .. _makeId] = function(...)
			finish = true
			toreturn = (...)
		end
		local _yield = task.spawn(function()
			table.insert(_currentIdentifier, { _makeId, tosend })
		end)
		while not finish do
			if _findIdentifier(self.remoteName) == false or (tick() - _t) >= timeout then
				finish = true
				task.cancel(_yield)
				break
			end
			task.wait()
		end
		_signals[self.remoteName]["_invokeSignal" .. _makeId] = nil
		return toreturn
	end
	return nil
end
function Client.pull(self: Client, timeout: number, ...: any): any?
	return self.Pull(self, timeout, ...)
end
function Client.Wait(self: Client): number -- EXPERIMENTAL
	local _now, this = os.clock(), _createId()
	local val, _on = 0, true
	_signals[self.remoteName]["_signal" .. this] = function()
		val = os.clock()
		_on = false
		_signals[self.remoteName]["_signal" .. this] = nil
	end
	repeat
		task.wait()
	until _on == false and _findIdentifier(self.remoteName)
	return (val - _now)
end
function Client.wait(self: Client): number
	return self.Wait(self)
end
function Client.Listen(self: Client, waitTill: boolean | any, callback: any): Tany
	if typeof(waitTill) == "boolean" and waitTill == true then
		if self.__disconnected then
			self.__disconnected = false
		end
		repeat
			task.wait()
		until self.__disconnected == false and IsExist(self.remoteName) == true
		__callbacks[self.remoteName] = {
			func = callback or nil,
		}
	else
		__callbacks[self.remoteName] = {
			func = waitTill or nil,
		}
	end
	__callbacks[self.remoteName]["_type"] = __nets[self.remoteName]._type
	if not table.isfrozen(self) then
		return table.freeze(self)
	else
		return self
	end
end
function Client.listen(self: Client, waitTill: boolean | any, callback: any): Tany
	return self.Listen(self, waitTill, callback)
end
function Client.Once(self: Client, waitTill: boolean | any, callbacks: any)
	self:Listen(waitTill, callbacks)
	if __callbacks[self.remoteName] then
		__callbacks[self.remoteName]["_once"] = true
	end
end
function Client.once(self: Client, waitTill: boolean | any, callbacks: any)
	return self.Once(self, waitTill, callbacks)
end
function Client.Disconnect(self: Client, message: string?)
	if self and self.__disconnected == false then
		self.__disconnected = true
		__callbacks[self.remoteName] = nil
		if message and typeof(message) == "string" and message:len() > 0 then
			Debug.__direct_debug(message:len() <= 0, "[FastNet2]: " .. message, 2)
		end
	elseif self then
		Debug.__direct_debug(1 ~= 1, string.format("[FastNet2]: Unable to disconnect -> %s", Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName)), 2, nil, Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName))
	end
end
function Client.disconnect(self: Client, message: string?)
	return self.Disconnect(self, message)
end
function Client.Disconnected(self: Client): boolean
	return self.__disconnected
end
function Client.disconnected(self: Client): boolean
	return self.Disconnected(self)
end
function Client.logs(self: Client)
	return Debug.get_log(Driver.dec(FastNet2.Settings.useb64 or false, self.remoteName))
end
function Client.Destroy(self: Client)
	if self and __nets[self.remoteName] ~= nil then
		__nets[self.remoteName] = nil
		__callbacks[self.remoteName] = nil
		_signals[self.remoteName] = nil
		self.__disconnected = true
		_removeIdentifier(self.remoteName)
	end
end
function Client.destroy(self: Client)
	self.Destroy(self)
end

--// APIs

function FastNet2.getdebugcaches(): Tany
	return Debug.get_log()
end

function FastNet2.CreateUUID(): string
	return Driver.CreateUUID()
end

function FastNet2.randStr(length: number?): number | string
	return _createId(length)
end

function FastNet2.randNum(min: number, max: number, NewInt: boolean?): number
	return randNum(min, max, NewInt)
end

function FastNet2.toBestFormNum(num: number): number | string
	return Driver.toBestFormNum(num)
end

function FastNet2.delta(convert: boolean?)
	if convert then
		return (1 / RunService.Heartbeat:Wait())
	end
	return RunService.Heartbeat:Wait()
end

function FastNet2.Nearest(player: Player, radiusDist: any, customCharacter: boolean?): { Player }
	return Driver.Nearest(player, radiusDist, customCharacter)
end

function FastNet2.nearest(player: Player, radiusDist: any, customCharacter: boolean?): { Player }
	return FastNet2.Nearest(player, radiusDist, customCharacter)
end

function FastNet2.Wait(): number
	--[[
	Somereason just use PostSimulator as Heartbeat because Heartbeat only fire after Render Signal fire here why if the server/client dropped frame
	could be bad, PostSimulator is the new of Heartbeat, PostSimultion dont need to wait until Render Signal fired.
	PostSimulation is 1/60 or print(RunService.PostSimulation:Wait())
	]]
	--
	return RunService.PostSimulation:Wait()
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
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2, remoteName)
	return IsExist(Driver.enc(FastNet2.Settings.useb64 or false, remoteName))
end

function FastNet2:Get(remoteName: string, waitFor: number?)
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2, remoteName)
	remoteName = Driver.enc(FastNet2.Settings.useb64 or false, remoteName)
	Debug.__direct_debug(__nets[remoteName] ~= nil, "[FastNet2]: Remote not found, Require :Create first.", 2, nil, Driver.dec(FastNet2.Settings.useb64 or false, remoteName))
	if waitFor and typeof(waitFor) == "number" then
		if waitFor < 5 then
			waitFor = 5
		elseif waitFor > 15 then
			waitFor = 15
		end
		local finish, _t = false, tick()
		local _yield = task.spawn(function()
			repeat
				finish = IsExist(remoteName)
				task.wait()
			until finish == true
			finish = true
		end)
		while not finish do
			if (tick() - _t) >= waitFor and not finish then
				finish = true
				task.cancel(_yield)
				Debug.__direct_debug(1 ~= 1, string.format("[FastNet2]: Unable to retrieve %s (timed-out yield)", remoteName), 2)
				break
			end
			task.wait()
		end
	end
	_createSignal(remoteName)
	_createIdentifier(remoteName)
	if IsClient then
		return Client.new(remoteName, __nets[remoteName]._type)
	else
		return Server.new(remoteName, __nets[remoteName]._type)
	end
end

function FastNet2:get(remoteName: string, waitFor: number?): Tany
	return self:Get(Driver.enc(FastNet2.Settings.useb64 or false, remoteName), waitFor or 5)
end

function FastNet2:Create(remoteName: string, typeRemote: string)
	Debug.__direct_debug(typeof(remoteName) == "string", "[FastNet2]: Invalid type of remote name", 3, 2)
	Debug.__direct_debug(typeof(typeRemote) == "string", "[FastNet2]: Invalid type of remote", 3, 2)
	local enc_name = Driver.enc(FastNet2.Settings.useb64 or false, remoteName)
	if enc_name and not IsExist(enc_name) then
		if typeof(typeRemote) == "string" then
			typeRemote = typeRemote:lower()
			if
				typeRemote == "event"
				or typeRemote == "events"
				or typeRemote == "remoteevent"
				or typeRemote == "remoteevents"
				or typeRemote == "re"
				or typeRemote == "remote"
				or typeRemote == "remotes"
			then
				__nets[enc_name] = {
					_type = "re",
					name = enc_name,
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
				__nets[enc_name] = {
					_type = "rf",
					name = enc_name,
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
	function FastNet2._setdebug(silent: boolean)
		Debug.__direct_debug(typeof(silent) == "boolean", "[FastNet2]: Invalid type of debug option", 2)
		Debug.silentDebug(silent)
	end
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
						for index, data in v do
							if __callbacks[identifier] ~= nil then
								if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
									local _call = __callbacks[identifier]["func"](plr, table.unpack(data[2] or {}))
									table.insert(to_returns_invoke, { data[1], { _call } })
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
									if __callbacks[identifier] ~= nil then
										if FastNet2.Settings._enableEncoding and typeof(data) == "table" then
											for indexs, to_encode in data do
												data[indexs] = Driver.dec(FastNet2.Settings.useb64 or false, to_encode)
											end
										end
										Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									end
									for _index, datas in table.unpack(v) do
										if
											typeof(_index) == "number"
											and typeof(datas) == "table"
											and datas[1] ~= nil
										then
											if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
												if
													_signals[identifier] ~= nil
													and _signals[identifier]["_invokeSignal" .. datas[1]] ~= nil
												then
													Threads(
														_signals[identifier]["_invokeSignal" .. datas[1]],
														table.unpack(datas[2] or {})
													)
												end
											elseif
												plr
												and identifier ~= nil
												and __callbacks[identifier] ~= nil
												and __callbacks[identifier]["func"] ~= nil
											then
												if FastNet2.Settings._enableEncoding and typeof(datas) == "table" then
													for indexs, to_encode in datas do
														datas[indexs] =
															Driver.dec(FastNet2.Settings.useb64 or false, to_encode)
													end
												end
												Threads(__callbacks[identifier]["func"], plr, table.unpack(datas or {}))
											else
												v[_index] = nil
											end
										elseif
											plr
											and identifier ~= nil
											and __callbacks[identifier] ~= nil
											and __callbacks[identifier]["func"] ~= nil
											and datas ~= nil
										then
											local _cb = { datas }
											if FastNet2.Settings._enableEncoding then
												for indexs, to_encode in _cb do
													if typeof(to_encode) == "table" then
														for _i, x in to_encode do
															_cb[indexs][_i] =
																Driver.dec(FastNet2.Settings.useb64 or false, x)
														end
													else
														_cb[indexs] =
															Driver.dec(FastNet2.Settings.useb64 or false, to_encode)
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
									if __callbacks[identifier] ~= nil then
										if FastNet2.Settings._enableEncoding and typeof(data) == "table" then
											for indexs, to_encode in data do
												data[indexs] = Driver.dec(FastNet2.Settings.useb64 or false, to_encode)
											end
										end
										Threads(__callbacks[identifier]["func"], plr, table.unpack(data or {}))
									end
								end
								if
									__callbacks[identifier]
									and
									__callbacks[identifier]["_once"] ~= nil
									and __callbacks[identifier]["_once"] == true
								then
									__callbacks[identifier] = nil
								end
							end
						end
						if _toSend[identifier] and #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], { plr, to_returns_invoke })
							table.clear(to_returns_invoke) -- prevent memory leaks?
						end
						--task.spawn(function()
						--	if _signals[identifier] then
						--		debug.profilebegin("signal")
						--		for i, _call in _signals[identifier] do
						--			if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
						--				task.spawn(_call)
						--			end
						--		end
						--		debug.profileend()
						--	end
						--end)
					elseif -- invoke response
						_findIdentifier(identifier) and IsExist(identifier)
					then
						for index, datas in table.unpack(v) do
							if
								typeof(index) == "number"
								and typeof(datas) == "table"
								and _signals[identifier] ~= nil
								and _signals[identifier]["_invokeSignal" .. datas[1]] ~= nil
							then
								Threads(_signals[identifier]["_invokeSignal" .. datas[1]], table.unpack(datas[2] or {}))
							end
						end
						--task.spawn(function()
						--	if _signals[identifier] then
						--		debug.profilebegin("signal")
						--		for i, _call in _signals[identifier] do
						--			if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
						--				task.spawn(_call)
						--			end
						--		end
						--		debug.profileend()
						--	end
						--end)
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
						for index, data in _data do
							if __callbacks[identifier] ~= nil then
								if typeof(data) == "table" and typeof(data[1]) == "number" and _signals[identifier] then
									local _call = __callbacks[identifier]["func"](table.unpack(data[2] or {}))
									table.insert(to_returns_invoke, { data[1], { _call } })
								elseif typeof(data[1]) == "table" then
									if __callbacks[identifier] ~= nil then
										Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
									end
									for _index, datas in table.unpack(_data) do
										if
											typeof(_index) == "number"
											and typeof(datas) == "table"
											and datas[1] ~= nil
										then
											if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
												if
													_signals[identifier] ~= nil
													and _signals[identifier]["_invokeSignal" .. datas[1]] ~= nil
												then
													Threads(
														_signals[identifier]["_invokeSignal" .. datas[1]],
														table.unpack(datas[2] or {})
													)
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
								if
									__callbacks[identifier]
									and
									__callbacks[identifier]["_once"] ~= nil
									and __callbacks[identifier]["_once"] == true
								then
									__callbacks[identifier] = nil
								end
							end
						end
						if #to_returns_invoke > 0 then
							table.insert(_toSend[identifier], to_returns_invoke)
							table.clear(to_returns_invoke) -- prevent memory leaks?
						end
						--task.spawn(function()
						--	if _signals[identifier] then
						--		debug.profilebegin("signal")
						--		for i, _call in _signals[identifier] do
						--			if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
						--				task.spawn(_call)
						--			end
						--		end
						--		debug.profileend()
						--	end
						--end)
					elseif -- invoke response
						_findIdentifier(identifier) and IsExist(identifier)
					then
						for index, datas in table.unpack(_data) do
							if typeof(index) == "number" and typeof(datas) == "table" and datas[1] ~= nil then
								if typeof(datas[1]) == "number" or typeof(datas[1]) == "string" then
									if
										_signals[identifier] ~= nil
										and _signals[identifier]["_invokeSignal" .. datas[1]] ~= nil
									then
										Threads(
											_signals[identifier]["_invokeSignal" .. datas[1]],
											table.unpack(datas[2] or {})
										)
									else
										if not _reDo[identifier] then
											_reDo[identifier] = {}
										end
										table.insert(_reDo[identifier], _data)
									end
								end
							end
						end
						--task.spawn(function()
						--	if _signals[identifier] then
						--		debug.profilebegin("signal")
						--		for i, _call in _signals[identifier] do
						--			if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
						--				task.spawn(_call)
						--			end
						--		end
						--		debug.profileend()
						--	end
						--end)
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
	if (os.clock() - __t) >= (FastNet2.Settings.smooth_mode or (1 / 60 - 0.00015)) then -- lock frame (prevention frame exploit) & so we don't skip any/1 frame, => 60 frames per second?
		debug.profilebegin("FastNet2.Internal.process")
		if IsClient then
			task.spawn(function()
				debug.profilebegin("redo")
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
							for index, data in _data do
								if __callbacks[identifier] ~= nil then
									if
										typeof(data) == "table"
										and typeof(data[1]) == "number"
										and _signals[identifier]
									then
										local _call = __callbacks[identifier]["func"](table.unpack(data[2] or {}))
										table.insert(to_returns_invoke, { data[1], { _call } })
									else
										if __callbacks[identifier] ~= nil then
											Threads(__callbacks[identifier]["func"], table.unpack(data or {}))
										else
											for index, datas in table.unpack(_data) do
												if
													typeof(index) == "number"
													and typeof(datas) == "table"
													and _signals[identifier] ~= nil
													and _signals[identifier]["_invokeSignal" .. datas[1]] ~= nil
												then
													Threads(
														_signals[identifier]["_invokeSignal" .. datas[1]],
														table.unpack(datas[2] or {})
													)
												end
											end
										end
									end
									if
										__callbacks[identifier]
										and
										__callbacks[identifier]["_once"] ~= nil
										and __callbacks[identifier]["_once"] == true
									then
										__callbacks[identifier] = nil
									end
									table.remove(_data, index)
								end
							end
							--task.spawn(function()
							--	if _toSend[identifier] and #to_returns_invoke > 0 then
							--		table.insert(_toSend[identifier], to_returns_invoke)
							--	end
							--	if _signals[identifier] then
							--		for i, _call in _signals[identifier] do
							--			if typeof(i) == "string" and i:sub(1, 7) == "_signal" then
							--				task.spawn(_call)
							--			end
							--		end
							--	end
							--end)
						end
					end
				end
				debug.profileend()
			end)
		end
		if IsServer and FastNet2.Settings.waitPlr then
			task.spawn(function()
				debug.profilebegin("hold")
				for player: string, data in _onHold do
					if #data == 0 then
						continue
					end
					for identifier: string, datas in data do
						if typeof(datas) == "table" and #datas > 0 then
							for index: number, _data in datas do
								if
									_findIdentifier(identifier)
									and IsExist(identifier)
									and _data
									and player
									and Players[player]
								then
									if FastNet2.Settings.waitPlr and PlayerStatus[player] == true then
										_NetEvent:FireClient(Players[player], { [identifier] = _data })
									elseif not FastNet2.Settings.waitPlr then
										_NetEvent:FireClient(Players[player], { [identifier] = _data })
									end
									table.remove(datas, index)
								end
							end
						end
					end
				end
				debug.profileend()
			end)
		end
		local to_send: Tany = {
			["Server"] = {},
			["Client"] = {},
		} -- middleware
		local __reach_s_max: boolean = false
		local __reach_c_max: boolean = false
		local __Sindex: any = 0
		local __Cindex: any = 0
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
				if IsExist(identifier) and _findIdentifier(identifier) then
					-- encode
					if FastNet2.Settings._enableEncoding then
						debug.profilebegin("encode_" .. identifier)
						if identifier and typeof(packages) == "table" and #packages > 0 then
							for i, datas in packages do
								if typeof(datas) == "table" then
									for index, _d in datas do
										packages[i][index] = Driver.enc(FastNet2.Settings.useb64 or false, _d)
									end
								else
									packages[i] = Driver.enc(FastNet2.Settings.useb64 or false, datas)
								end
							end
						end
						debug.profileend()
					end
					to_send["Client"][identifier] = packages
					__Cindex += 1
					_wipeIdentifier(identifier)
					if _signals[identifier] then
						for __, _s in _signals[identifier] do
							Threads(_s)
						end
					end
				end
			elseif IsServer then -- is server
				if __reach_s_max then
					continue
				end
				if to_send["Server"][identifier] ~= nil or #_getIdentifier(identifier) <= 0 then
					continue
				end
				task.spawn(function()
					if IsExist(identifier) and _findIdentifier(identifier) then
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
						if not to_send["Server"][identifier] then
							continue
						end
						if index and data then
							if typeof(data[1]) == "Instance" then
								if not to_send_to_client[identifier] then
									to_send_to_client[identifier] = {}
									to_send_to_client[identifier][data[1]] = {}
								end
								if to_send_to_client[identifier] and to_send_to_client[identifier][data[1]] then
									table.insert(to_send_to_client[identifier][data[1]], data[2])
									to_send_indexs += 1
									if _signals[identifier] then
										for __, _s in _signals[identifier] do
											Threads(_s)
										end
									end
								end
							else
								if not to_send_all_clients[identifier] then
									to_send_all_clients[identifier] = {}
								end
								table.insert(to_send_all_clients[identifier], data[2])
								to_send_all_indexs += 1
								if _signals[identifier] then
									for __, _s in _signals[identifier] do
										Threads(_s)
									end
								end
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
							if not to_send_to_client[identifier] then
								continue
							end
							if player and _data then
								-- local _convert = {}
								-- _convert[identifier] = _data
								task.spawn(function()
									if player and FastNet2.Settings.waitPlr and PlayerStatus[player.Name] == true then
										_NetEvent:FireClient(player, { [identifier] = _data })
									elseif player and not FastNet2.Settings.waitPlr then
										_NetEvent:FireClient(player, { [identifier] = _data })
									elseif player then
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
								end)
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
		debug.profileend()
		table.clear(to_send) -- prevent memory leaks?
		__Cindex = nil
		__Sindex = nil
		__t = os.clock()
	end
end)

if IsServer and FastNet2.Settings.waitPlr then
	repeat task.wait() until #Players:GetPlayers() > 0
	for i, player in pairs(Players:GetPlayers()) do
		task.spawn(_loadPlrStatus, player)
	end
end

reConfigure()

Debug.__direct_debug(
	1 ~= 1,
	string.format(
		"FastNet2 initialized [ver_%s (%s) <- %s | %s | %sms]",
		FastNet2.version,
		tostring(FastNet2.build),
		FastNet2.production,
		__getProvider(),
		(tick() - __load_s) * 1000
	),
	2
)

return table.freeze(FastNet2)
