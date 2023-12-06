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

-- Create session semiliar with task.wait function (Internal Function)
function Util.Session(timeout: number)
	local afterSession, arguments, private = nil, {}, {}
	local session = task.delay(math.max(0.5, timeout), function()
		if afterSession and typeof(afterSession) == "function" then
			task.spawn(afterSession, table.unpack(arguments))
		end
	end)
	function private:After(func: (...any) -> (), ...: any)
		afterSession = func
		arguments = { ... }
		return private
	end
	function private:Cancel()
		task.cancel(session)
	end
	return private
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
			task.wait(0.5)
		end
	end
	return Event:GetAttribute(identifier)
end

return table.freeze(Util)