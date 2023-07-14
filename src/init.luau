--!strict
-- FastNet2
-- Author: @EternityDev (Eternity_Devs)

local FastNet2 = {}
FastNet2.__index = FastNet2
FastNet2.version = "rc2"

local RunService = game:GetService("RunService")

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

if RunService:IsServer() then
	return setmetatable(FastNet2, require(script.Server))
end
return setmetatable(FastNet2, require(script.Client))
