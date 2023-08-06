--!strict
local ClientIdentifier = {}

local Identifiers: {[string]: boolean} = {}

function ClientIdentifier.find(Identifier: string): boolean
	return Identifiers[Identifier] == true
end

function ClientIdentifier.reg(Identifier: string): boolean
	if not ClientIdentifier.find(Identifier) then
		Identifiers[Identifier] = true
		return true
	end
	return false
end

function ClientIdentifier.unreg(Identifier: string): boolean
	if ClientIdentifier.find(Identifier) then
		Identifiers[Identifier] = false
		return true
	end
	return false
end

return table.freeze(ClientIdentifier) :: typeof(ClientIdentifier)
