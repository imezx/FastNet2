--!native
--!strict
-- FastNet2
-- Author: @EternityDev (Eternity_Devs)
-- version rc9 (0.9.3)

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = 0.9

local IsServer: boolean = game:GetService("RunService"):IsServer()
local HttpService = game:GetService("HttpService")

if not script:FindFirstChild("Event") then
	Instance.new("RemoteEvent", script).Name = "Event"
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
	if IsServer then
		local success: boolean, receive: number = pcall(function()
			return tonumber(
				HttpService:GetAsync("https://raw.githubusercontent.com/imezx/FastNet2/master/VERSION", true)
			) :: number
		end)
		if not success then
			return warn("[FastNet2]: Failed to check update.")
		end
		if receive > FastNet2.version then
			return warn(string.format("[FastNet2]: new update available with version: %s current: %s", tostring(receive), tostring(FastNet2.version)))
		end
		return warn("[FastNet2]: Module is up-to-date.")
	end
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

function FastNet2.debugLogs()
	return Debug.receiveAll()
end

if IsServer then
	return setmetatable(FastNet2, require(script.Server))
end
return setmetatable(FastNet2, require(script.Client))