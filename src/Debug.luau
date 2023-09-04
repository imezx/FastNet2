--!strict

local Debug = {}
Debug.debugging = true

local Logs = {}

function Debug._debug(opt: boolean)
	Debug.new(typeof(opt) == "boolean", "[FastNet2]: argument 1 must be a boolean")
	Debug.debugging = opt
end

function Debug.new(condition: any, message: string): boolean
	if Debug.debugging and not (condition) then table.insert(Logs, message) error(message, 2) end
	return (condition)
end

function Debug.receiveAll()
	return Logs
end

return Debug