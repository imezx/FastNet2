--!strict
-- FastNet2 Utilities

local Util = {}
Util.HashCache = {}

local HttpService = game:GetService("HttpService")

function Util.CreateUUID(): string
	return string.gsub(HttpService:GenerateGUID(false), "-", "") :: string
end

-- Optimized Luau Hash with caching
function Util.hash(data: string | number | boolean): string
	if typeof(data) == "string" then
		if not Util.HashCache[data] then
			local hash: any = 0
			for i = 1, #data do
				-- (hash * 32) - hash + string.byte(data, i) for fastest method
				hash = (hash * 31 + string.byte(data, i)) % 2^32 -- this for better quality of hash
			end
			hash = tostring(hash)
			Util.HashCache[data] = hash -- make it cached the hash
			return hash
		end
		return Util.HashCache[data]
	elseif typeof(data) == "number" then
		return tostring(data)
	elseif typeof(data) == "boolean" then
		return (data and "\1" or "\0")
	end
	return data
end

return Util