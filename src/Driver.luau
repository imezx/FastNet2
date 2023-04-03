-- FastNet2 Drivers
--!strict
local Driver = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local base64 = require(script:WaitForChild("b64"))

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

function Driver.Nearest(player: Player, radiusDist: any, customCharacter: boolean?): {[string]: number}
	local InNearest: any = {}
	radiusDist = tonumber(radiusDist)
	assert(typeof(radiusDist) == "number", "Invalid argument radiusDist")
	assert(radiusDist > 0 , "Minimum argument radiusDist is > 0")
	if player and #Players:GetPlayers() > 0 then
		for _, plr: Player in ipairs(Players:GetPlayers()) do
			if plr and plr:IsA("Player") then
				if player and player:IsA("Player") and player.Character and plr and plr.Character then
					if not customCharacter then
						if player.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("HumanoidRootPart") ~= plr.Character:FindFirstChild("HumanoidRootPart") then
							local distance = (player.Character:WaitForChild("HumanoidRootPart").Position - plr.Character:WaitForChild("HumanoidRootPart").Position).Magnitude
							if distance <= tonumber(radiusDist) then
								InNearest[plr.Name] = distance
							end
						end
					elseif customCharacter then
						if player.Character.PrimaryPart ~= nil and player.Character.PrimaryPart:IsA("BasePart") and plr.Character.PrimaryPart ~= nil and plr.Character.PrimaryPart:IsA("BasePart") and player.Character.PrimaryPart ~= plr.Character.PrimaryPart then
							local distance = (player.Character.PrimaryPart.Position - plr.Character.PrimaryPart.Position).Magnitude
							if distance <= tonumber(radiusDist) then
								InNearest[plr.Name] = distance
							end
						end
					end
				elseif plr and plr.Character and player and player:IsA("BasePart") then
					if not customCharacter then
						if plr.Character:FindFirstChild("HumanoidRootPart") and player ~= plr.Character:FindFirstChild("HumanoidRootPart") then
							local distance = (player.Character:WaitForChild("HumanoidRootPart").Position - plr.Character:WaitForChild("HumanoidRootPart").Position).Magnitude
							if distance <= tonumber(radiusDist) then
								InNearest[plr.Name] = distance
							end
						end
					elseif customCharacter then
						if player:IsA("BasePart") and plr.Character.PrimaryPart ~= nil and plr.Character.PrimaryPart:IsA("BasePart") and player ~= plr.Character.PrimaryPart then
							local distance = (player.Position - plr.Character.PrimaryPart.Position).Magnitude
							if distance <= tonumber(radiusDist) then
								InNearest[plr.Name] = distance
							end
						end
					end
				end
			end
		end
	end
	return InNearest
end

-- Encode & Decoding Binary 2.0 + Base64 (Beta)
-- Massively better efficience and fast on encode & decode binary only take 1.04-1.08s only for 9k loops to encode & decode in the same time.
--[[
Example benchmark test code:
local m = "abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_-+=,./?';:]}[{\|~`"
task.wait(3.5)
print("start")
local t = os.clock()

-- benchmark (9k loops total)
for i=1,1500 do
	for i=1,6 do
		x.dec(false, x.enc(falsem m..i))
	end
end
print(os.clock() - t)

-- only took 0.000169s - 0.000378s for once encode & decode binary
code:
local m = "abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_-+=,./?';:]}[{\|~`"
local t = os.clock()
x.dec(false, x.enc(false, m))
print(os.clock() - t)
]]
function encodeTable(b64: boolean, data): any
	for i, datas in data do
		if typeof(datas) == "number" or tonumber(datas) ~= nil then
			datas = tostring(datas)
		end
		if typeof(datas) == "string" then
			if b64 then
				data[i] = base64.enc(datas)
			else
				local binary = ""
				for i = 1, #datas do
					local byte = string.byte(datas, i)
					for j = 7, 0, -1 do
						binary ..= bit32.band(bit32.rshift(byte, j), 1)
					end
				end
				data[i] = binary
			end
		elseif typeof(datas) == "table" then
			if #datas == 0 then
				continue
			else
				-- alternative check
				local x: any = 0
				for _i,n in datas do
					x += 1
					break
				end
				if x <= 0 then
					x = nil
					continue
				end
			end
			data[i] = encodeTable(b64, datas)
		end
	end
	return data
end
function decodeTable(b64: boolean, data): any
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
				local index = 1
				local str: any = ""
				while index <= #datas do
					local byteBinary = datas:sub(index, index + 7)
					str ..= string.char(tonumber(byteBinary, 2))
					index += 8
				end
				if tonumber(str) ~= nil then
					data[i] = tonumber(str)
				else
					data[i] = str
				end
			end
		elseif typeof(datas) == "table" then
			if #datas == 0 then
				continue
			else
				-- alternative check
				local x: any = 0
				for _i,n in datas do
					x += 1
					break
				end
				if x <= 0 then
					x = nil
					continue
				end
			end
			data[i] = decodeTable(b64, datas)
		end
	end
	return data
end

function Driver.enc(b64: boolean, data: any): any
	if typeof(data) == "number" or tonumber(data) ~= nil then
		data = tostring(data)
	end
	if typeof(data) == "string" then
		if data and data:len() > 0 then
			if b64 then
				return base64.enc(data) or data
			end
			local binary = ""
			for i = 1, #data do
				local byte = string.byte(data, i)
				for j = 7, 0, -1 do
					binary ..= bit32.band(bit32.rshift(byte, j), 1)
				end
			end
			return binary
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
					local binary = ""
					for i = 1, #data do
						local byte = string.byte(data, i)
						for j = 7, 0, -1 do
							binary ..= bit32.band(bit32.rshift(byte, j), 1)
						end
					end
					data[i] = binary
				end
			elseif typeof(datas) == "table" then
				if #datas == 0 then
					continue
				else
					-- alternative check
					local x: any = 0
					for _i,n in datas do
						x += 1
						break
					end
					if x <= 0 then
						x = nil
						continue
					end
				end
				data[i] = encodeTable(b64, datas)
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
		local index = 1
		local str: any = ""
		while index <= #data do
			local byteBinary = data:sub(index, index + 7)
			str ..= string.char(tonumber(byteBinary, 2))
			index += 8
		end
		if tonumber(str) ~= nil then
			return tonumber(str)
		else
			return str
		end
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
					local index = 1
					local str: any = ""
					while index <= #datas do
						local byteBinary = datas:sub(index, index + 7)
						str ..= string.char(tonumber(byteBinary, 2))
						index += 8
					end
					if tonumber(str) ~= nil then
						data[i] = tonumber(str)
					else
						data[i] = str
					end
				end
			elseif typeof(datas) == "table" then
				if #datas == 0 then
					continue
				else
					-- alternative check
					local x: any = 0
					for _i,n in datas do
						x += 1
						break
					end
					if x <= 0 then
						x = nil
						continue
					end
				end
				data[i] = decodeTable(b64, datas)
			end
		end
	end
	return data
end

return table.freeze(Driver)
