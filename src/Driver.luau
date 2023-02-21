-- FastNet2 Drivers
--!strict
local Driver = {}
local HttpService = game:GetService("HttpService")
local base64 = require(script.Parent:WaitForChild("b64"))

function Driver.CreateUUID(): string
	return string.gsub(HttpService:GenerateGUID(false), "-", "")
end

function Driver.toBestFormNum(num: number): number | string
	local _tostring = tostring(num)
	if #_tostring <= 7 then
		return _tostring
	else
		return num
	end
end

-- Encode & Decoding Binary 1.0 + Base64 (Beta)
function Driver.enc(b64, data: any): any
	if typeof(data) == "number" or tonumber(data) ~= nil then
		data = tostring(data)
	end
	if typeof(data) == "string" then
		if data and data:len() > 0 then
			if b64 then
				return base64.enc(data) or data
			end
			local toBinary = {}
			for i, Character in ipairs(data:split('')) do
				local binary = ""
				local byte = Character:byte()
				while (byte > 0) do
					binary = (byte % 2) .. binary
					byte = math.modf(byte / 2)
				end
				table.insert(toBinary, string.format("%.8d", binary))
			end
			return table.concat(toBinary, " ")
		end
		return data
	elseif typeof(data) == "table" then
		for i,datas in data do
			if typeof(datas) == "number" or tonumber(datas) ~= nil then
				datas = tostring(datas)
			end
			if typeof(datas) == "string" then
				if b64 then
					data[i] = base64.enc(datas)
				else
					local toBinary = {}
					for i, Character in ipairs(datas:split('')) do
						local binary = ""
						local byte = Character:byte()
						while (byte > 0) do
							binary = (byte % 2) .. binary
							byte = math.modf(byte / 2)
						end
						table.insert(toBinary, string.format("%.8d", binary))
					end
					data[i] = table.concat(toBinary, " ")
				end
			end
		end
	end
	return data
end

function Driver.dec(b64, data: any): any
	if typeof(data) == "string" and data:len() > 0 then
		if b64 then
			-- error handling
			local x,y = pcall(function()
				return base64.dec(data)
			end)
			if not x then
				return data
			end
			return y
		end
		local str = ""
		for _, binary in ipairs(data:split(" ")) do
			str ..= string.char(tonumber(binary, 2))
		end
		if tonumber(str) ~= nil then
			return tonumber(str)
		end
		return str
	elseif typeof(data) == "table" then
		for i, datas in data do
			if typeof(datas) == "string" and datas:len() > 0 then
				if b64 then
					-- error handling
					local x,y = pcall(function()
						return base64.dec(datas)
					end)
					if not x then
						data[i] = datas
					else
						data[i] = y
					end
				else
					local str = ""
					for _, binary in ipairs(datas:split(" ")) do
						str ..= string.char(tonumber(binary, 2))
					end
					if tonumber(str) ~= nil then
						data[i] = tonumber(str)
					else
						data[i] = str
					end
				end
			end
		end
	end
	return data
end

return table.freeze(Driver)