local Debug = {}

local IsDebugging = false
local Logs = {}

function Debug._debug(opt: boolean)
	Debug.new(typeof(opt) == "boolean", "[FastNet2]: argument 1 must be a boolean")
	IsDebugging = opt
end

function Debug.new(condition: any, message: string): boolean
	if IsDebugging and not (condition) then table.insert(Logs, message) warn(message) end
	return (condition)
end

function Debug.receiveAll()
	return Logs
end

return Debug