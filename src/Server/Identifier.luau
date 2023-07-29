local ClientIdentifier = {}
ClientIdentifier.Identifier = {}

function ClientIdentifier.find(Identifier)
	return ClientIdentifier.Identifier[Identifier] ~= nil and true or false
end

function ClientIdentifier.reg(Identifier)
	if not ClientIdentifier.find(Identifier) then
		ClientIdentifier.Identifier[Identifier] = true
	end
	return ClientIdentifier.Identifier[Identifier]
end

function ClientIdentifier.unreg(Identifier)
	if ClientIdentifier.find(Identifier) then
		ClientIdentifier.Identifier[Identifier] = nil
		return true
	end
	return false
end

return ClientIdentifier