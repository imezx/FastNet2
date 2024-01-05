--!native
--!strict
-- FastNet2
-- Author: @EternityDev (Eternity_Devs)
-- version rc9 (0.9.7)

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = 0.9

local IsServer: boolean = game:GetService("RunService"):IsServer()
local HttpService = game:GetService("HttpService")

if IsServer then
	if not script:FindFirstChild("Event") then
		Instance.new("RemoteEvent", script).Name = "Event"
	end
	if not script:FindFirstChild("UnreliableEvent") then
		Instance.new("UnreliableRemoteEvent", script).Name = "UnreliableEvent"
	end
else
	if not script:FindFirstChild("Event") or not script:FindFirstChild("UnreliableEvent") then
		warn("[FastNet2]: Waiting for initialize from server-side.")
		repeat task.wait() until script:FindFirstChild("Event") and script:FindFirstChild("UnreliableEvent")
	end
end

local Debug = require(script.Debug)
local Signal = require(script.oneSignal)
local Util = require(script.Util)

--[[**
	Custom Signal a alternative of BindableEvent (oneSignal, oneSignal.luau)

	@param Identifier The name of Signal (Identifier)

	@returns Signal
**--]]

function FastNet2.Signal(Identifier: string): typeof(Signal)
	local success, signal = pcall(function()
		return Signal.get(Identifier)
	end)
	if not success then
		return Signal.new(Identifier)
	end
	return signal
end

--[[**

	Check Update of FastNet2 Module through HttpService to Github

**--]]

function FastNet2.CheckUpdate()
	Debug.new(IsServer, "[FastNet2]: Unable to check update from client-side due ROBLOX Security.", 1)

	if not IsServer then return warn("[FastNet2] Only server can check the version!") end
	-- Funny way of doing it
	local success: boolean,recieve: string = pcall(
		HttpService.GetAsync,HttpService,"https://raw.githubusercontent.com/imezx/FastNet2/master/VERSION", true
	)

	if not success then
		return warn("[FastNet2]: Failed to check update.")
	end

	if tonumber(receive) > FastNet2.version then
		return warn(string.format("[FastNet2]: new update available with version: %s current: %s", receive, tostring(FastNet2.version)))
	end

	return warn("[FastNet2]: Module is up-to-date.")
end

--[[**

	Create a Universal Unique Identifier (UUID)

**--]]

function FastNet2.CreateUUID(): string
	return Util.CreateUUID()
end

--[[**

	Receive all fastnet2 debug logs
	
	@returns all debugging logs

**--]]

function FastNet2.debugLogs(): {any}
	return Debug.receiveAll()
end

if IsServer then
	return setmetatable(FastNet2, require(script.Server))
end
return setmetatable(FastNet2, require(script.Client))