--!native
--!strict
local ServerProcess = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Identifiers = require(script.Parent.Identifier)
local FastSpawn = require(script.Parent.Parent.FastSpawn)
local Event = script.Parent.Parent:WaitForChild("Event")

local Collections = {}

function ServerProcess.reg(Identifier: string)
	if Identifiers.reg(Identifier) then
		Collections[Identifier] = {
			Identifier = Identifier,
			_ping = {},
			returnRequest = {},
			re_req_i = 0,
			requests = {},
			req_i = 0,
			packets = {},
			single = {},
			_pre = {},
			_pre_p = {},
			_pre_f = nil,
		} :: any
	end
end

function ServerProcess.unreg(Identifier: string): boolean
	return Identifiers.unreg(Identifier) :: boolean
end

function ServerProcess.s_insert(Identifier: string, player: Player, obj)
	if not Collections[Identifier].single[player.Name] then
		Collections[Identifier].single[player.Name] = {}
	end
	table.insert(Collections[Identifier].single[player.Name], obj)
end

function ServerProcess.insert(Identifier: string, obj)
	table.insert(Collections[Identifier].packets, obj)
end

function ServerProcess.verify(Identifier: string, player: Player, reqId: number): boolean
	return Collections[Identifier].requests[player][reqId] ~= nil and true or false
end

function ServerProcess.newReq(Identifier: string, reqId: number, player: Player, obj)
	if not Collections[Identifier].requests[player] then
		Collections[Identifier].requests[player] = {}
	end
	Collections[Identifier].requests[player][reqId] = obj
	Collections[Identifier].req_i += 1
end

function ServerProcess.pushback(Identifier: string, player: string, id: number, obj)
	if not Collections[Identifier].returnRequest[player] then
		Collections[Identifier].returnRequest[player] = {}
	end
	Collections[Identifier].returnRequest[player][id] = obj
	Collections[Identifier].re_req_i += 1
end

function ServerProcess._ping(Identifier: string): number
	local thread, clock = coroutine.running(), os.clock()
	table.insert(Collections[Identifier]._ping, function(x: number)
		Collections[Identifier]._ping = nil
		task.spawn(thread, x - clock)
	end)
	return coroutine.yield()
end

function ServerProcess._pre(Identifier: string, player: Player, pre)
	ServerProcess.reg(Identifier)
	if not Collections[Identifier]._pre[player] then
		Collections[Identifier]._pre[player] = {}
	end
	table.insert(Collections[Identifier]._pre[player], pre)
end

function ServerProcess._pre_p(Identifier: string, player: Player, pre)
	ServerProcess.reg(Identifier)
	if not Collections[Identifier]._pre_p[player] then
		Collections[Identifier]._pre_p[player] = {}
	end
	table.insert(Collections[Identifier]._pre_p[player], pre)
end

function ServerProcess.reg_pre_f(Identifier: string, f)
	ServerProcess.reg(Identifier)
	Collections[Identifier]._pre_f = f
end

function ServerProcess.unreg_pre_f(Identifier: string)
	Collections[Identifier]._pre_f = nil
end

function ServerProcess.__start()
	local outQueue: { [string]: {any} }, outIndex: number = {}, 0
	local outSQueue: { [string]: {any} }, outSIndex: number = {}, 0
	RunService.PostSimulation:Connect(function()
		-- Sent all data to client (Multiple Players)
		if outIndex > 0 then
			outIndex = 0
			Event:FireAllClients(outQueue)
			table.clear(outQueue)
		end
		if outSIndex > 0 then
			for player, packet in outSQueue do
				if player and Players:FindFirstChild(player) and Event:GetAttribute(player) == true then
					outSIndex -= 1
					Event:FireClient(Players[player], packet)
					table.clear(packet)
				end
			end
		end
		debug.profilebegin("FastNet2.process")
		-- Connections Dataset from Collections
		for Identifier: string, net in Collections do
			if net._pre_f then
				for player, packet in net._pre do
					if player and Players:FindFirstChild(player.Name) then
						if #packet > 0 then
							for _, data in packet do
								FastSpawn(net._pre_f, table.unpack(data))
							end
							table.clear(packet)
						end
					elseif player and not Players:FindFirstChild(player.Name) then
						-- remove player from pre (player is left)
						net._pre[player] = nil
					end
				end
				for player, packet in net._pre_p do
					if player and Players:FindFirstChild(player.Name) then
						if #packet > 0 then
							for i, data in packet do
								FastSpawn(ServerProcess.pushback, Identifier, player.Name, i, net._pre_f(player, table.unpack(data)))
							end
							table.clear(packet)
						end
					elseif player and not Players:FindFirstChild(player.Name) then
						-- remove player from pre (player is left)
						net._pre_p[player] = nil
					end
				end
			end
			-- Multiple Players to Queue
			if #net.packets > 0 then
				outQueue[Identifier] = net.packets
				outIndex += 1
				net.packets = {}
			end
			-- Requests to Queue
			if net.req_i > 0 then
				for player, requests in net.requests do
					if player and Players:FindFirstChild(player.Name) and Event:GetAttribute(player.Name) == true then
						net.req_i -= 1
						Event:FireClient(player, "0", {[net.Identifier] = requests})
						table.clear(requests)
					end
				end
			end
			-- Return Requests
			if net.re_req_i > 0 then
				for player, data in net.returnRequest do
					if Players:FindFirstChild(player) and Event:GetAttribute(player) == true then
						net.re_req_i -= 1
						Event:FireClient(Players[player], "1", {[net.Identifier] = data})
						table.clear(data)
					end
				end
			end
			-- Single Players to Queue
			for player, packets in net.single do
				if #packets > 0 and Players:FindFirstChild(player) then
					if not outSQueue[player] then
						outSQueue[player] = {}
					end
					if not outSQueue[player][net.Identifier] then
						outSQueue[player][net.Identifier] = {}
					end
					outSQueue[player][net.Identifier] = table.clone(packets)
					table.clear(packets)
					outSIndex += 1
				end
			end
			-- Ping :Wait()
			if #net._ping > 0 then
				for _, func in net._ping do
					FastSpawn(func, os.clock())
				end
			end
		end
		debug.profileend()
	end)
end

return table.freeze(ServerProcess) :: typeof(ServerProcess)