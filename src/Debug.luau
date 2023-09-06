--!strict

local Debug = {}
local Logs = {}

function Debug.new(condition: any, message: string, safe: number): boolean
	if safe == 1 then
		if not (condition) then warn(message) end
	else
		table.insert(Logs, message.." ("..((condition) == true and "PASS" or "ERR")..")")
		if not (condition) then error(message, 2) end
	end
	return (condition)
end

function Debug.receiveAll()
	return Logs
end

return table.freeze(Debug) :: typeof(Debug)