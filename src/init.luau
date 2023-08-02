--!strict
-- FastNet2
-- Author: @EternityDev (Eternity_Devs)
-- version rc6 (0.6.1)

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = 0.61

local IsServer = game:GetService("RunService"):IsServer()
local HttpService = game:GetService("HttpService")

if not script:FindFirstChild("Event") then
	Instance.new("RemoteEvent", script).Name = "Event"
end

local Signal = require(script.oneSignal)

-- Signal (oneSignal, oneSignal.luau)
function FastNet2.Signal(Identifier: string)
	local Is, signal = pcall(function()
		return Signal.new(Identifier)
	end)
	if not Is then
		return Signal.get(Identifier)
	end
	return signal
end

function FastNet2.CheckUpdate()
	assert(IsServer, "[FastNet2]: Unable to check update due ROBLOX Security.")
	local success: boolean, receive: number = pcall(function()
		return tonumber(
			HttpService:GetAsync("https://raw.githubusercontent.com/imezx/FastNet2/master/VERSION", true)
		) :: number
	end)
	if not success then
		warn("[FastNet2]: Failed to check update.")
		return
	end
	if receive > FastNet2.version then
		warn(string.format("[FastNet2]: new update available with version: %s current: %s", tostring(receive), tostring(FastNet2.version)))
		return
	end
	warn("[FastNet2]: Module is up-to-date.")
end

function FastNet2.CreateUUID(): string
	return string.gsub(HttpService:GenerateGUID(false), "-", "") :: string
end

if IsServer then
	return setmetatable(FastNet2, require(script.Server))
end
return setmetatable(FastNet2, require(script.Client))
