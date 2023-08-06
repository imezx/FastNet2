--!strict
local ServerIdentifier = {}

local Identifiers: {[string]: boolean} = {}

function ServerIdentifier.find(Identifier: string): boolean
	return Identifiers[Identifier] == true
end

function ServerIdentifier.reg(Identifier: string): boolean
	if not ServerIdentifier.find(Identifier) then
		Identifiers[Identifier] = true
	end
	return Identifiers[Identifier]
end

function ServerIdentifier.unreg(Identifier: string): boolean
	if ServerIdentifier.find(Identifier) then
		Identifiers[Identifier] = false
		return true
	end
	return false
end

return table.freeze(ServerIdentifier) :: typeof(ServerIdentifier)
