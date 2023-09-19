--!native
--!strict
-- FastNet2 Utilities
local Util = {}

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Debug = require(script.Parent:WaitForChild("Debug"))

local Event = script.Parent:WaitForChild("Event")

local SerInt = 0

function Util.CreateUUID(): string
	return string.gsub(HttpService:GenerateGUID(false), "-", "") :: string
end

-- Create session semiliar with task.wait function (YIELD) (Internal Function)
function Util.Session(timeout: number): number
	local thread, n = coroutine.running(), tick()
	task.delay(math.max(0.25, timeout), function()
		task.spawn(thread, tick() - n)
	end)
	return coroutine.yield()
end

-- Generate a randomized unique number with 8 length num (Internal Function)
function Util.uniqueNum(): number
	local num: string = ""
	for i=1,8 do
		num ..= math.random(0, 9)
	end
	return tonumber(num) :: number
end

-- Serialize Identifier (Beta) (Internal Function) (https://www.lua.org/manual/5.3/manual.html#pdf-string.pack)
function Util.ser(identifier: string): string
	Debug.new(typeof(identifier) == "string", "[FastNet2]: Unable to serialize identifier (expected string got "..typeof(identifier)..", will convert to string)", 1)
	identifier = tostring(identifier)
	if RunService:IsServer() then
		if not Event:GetAttribute(identifier) then
			SerInt += 1
			Event:SetAttribute(identifier, string.pack("I1", SerInt)) -- I1 -> 255 max, I2 -> ~ 6.5e4 max. (SerInt)
		end
	else
		while not Event:GetAttribute(identifier) do
			print("e")
			Util.Session(0.5)
		end
	end
	return Event:GetAttribute(identifier)
end

return table.freeze(Util)