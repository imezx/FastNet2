-- FastNet2 Drivers
--!strict
local Driver = {}

-- Encode & Decoding Binary 1.0
function Driver.enc(data: any): any
	if typeof(data) == "string" or typeof(data) == "number" then
		if typeof(data) == "number" then
			data = tostring(data)
		end
		if data and data:len() > 0 then
			local toBinary = {}
			for i, Character in ipairs(data:split('')) do
				local binary = ""
				local byte = Character:byte()
				while (byte > 0) do
					binary = tostring(byte % 2) .. binary
					byte = math.modf(byte / 2)
				end
				table.insert(toBinary, string.format("%.8d", binary))
			end
			return table.concat(toBinary, " ")
		end
		return data
	end
	return data
end

function Driver.dec(data: any): any
	if typeof(data) == "string" and data:len() > 0 then
		local str = ""
		for _, binary in ipairs(data:split(" ")) do
			str ..= string.char(tonumber(binary, 2))
		end
		if tonumber(str) ~= nil then
			return tonumber(str)
		end
		return str
	end
	return data
end

return table.freeze(Driver)