--!native
--!strict
local ClientProcess = {}
ClientProcess.processLimit = 500 -- max rate process limit (default: 250)
ClientProcess.rateLimit = 500 -- max rate limit (default: 150)
ClientProcess.igroneOnLimit = 1 -- duration igroning the identifier when reaching rate limit (default: 1)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Identifiers = require(script.Parent.Identifier)
local FastSpawn = require(script.Parent.Parent.FastSpawn)
local Debug = require(script.Parent.Parent.Debug)

local Event: RemoteEvent = script.Parent.Parent:WaitForChild("Event")
local UnreliableEvent: UnreliableRemoteEvent = script.Parent.Parent:WaitForChild("UnreliableEvent")

local Collections = {}
local Outgoing = {}

function ClientProcess.reg(Identifier: string, reliable: boolean?)
	if not Identifiers.reg(Identifier) then return end
	if not Collections[Identifier] then
		Collections[Identifier] = {
			OutgoingOrder = 0,
			_ping = {},
			returnRequest = {},
			re_req_i = 0,
			requests = {},
			req_i = 0,
			_rate = os.clock(),
			_pre = {},
			_pre_p = {},
			_pre_f = nil,
			reliable = reliable or true,
		} :: any
		Outgoing[Identifier] = {}
	end
end

function ClientProcess.unreg(Identifier: string)
	if Identifiers.unreg(Identifier) then
		table.clear(Outgoing[Identifier])
	end
end

function ClientProcess.insert(Identifier: string, obj)
	if Collections[Identifier].OutgoingOrder >= ClientProcess.rateLimit then return warn("[FastNet2]: Unable to call :Fire (rate-limit reached)") end
	Collections[Identifier].OutgoingOrder += 1
	Outgoing[Identifier][Collections[Identifier].OutgoingOrder] = obj
end

function ClientProcess.verify(Identifier: string, reqId: string): boolean
	return Collections[Identifier].requests[reqId] ~= nil and true or false
end

function ClientProcess.newReq(Identifier: string, reqId: string, obj)
	Collections[Identifier].requests[reqId] = obj
	Collections[Identifier].req_i += 1
end

function ClientProcess.pushback(Identifier: string, id: string, obj)
	Collections[Identifier].returnRequest[id] = obj
	Collections[Identifier].re_req_i += 1
end

function ClientProcess._ping(Identifier: string): number
	local thread = coroutine.running()
	local clock = os.clock()
	table.insert(Collections[Identifier]._ping, function(x: number)
		Collections[Identifier]._ping = nil
		task.spawn(thread, x - clock)
	end)
	return coroutine.yield()
end

function ClientProcess._pre(Identifier: string, pre)
	ClientProcess.reg(Identifier)
	Collections[Identifier]._pre[#Collections[Identifier]._pre + 1] = pre
end

function ClientProcess._pre_p(Identifier: string, pre)
	ClientProcess.reg(Identifier)
	Collections[Identifier]._pre_p[#Collections[Identifier]._pre_p + 1] = pre
end

function ClientProcess.reg_pre_f(Identifier: string, f)
	ClientProcess.reg(Identifier)
	Collections[Identifier]._pre_f = f
end

function ClientProcess.unreg_pre_f(Identifier: string)
	Collections[Identifier]._pre_f = nil
end

function ClientProcess.__start()
	local outQueue: { [string]: {any} }, outIndex: number = {}, 0
	local outQueue2: { [string]: {any} }, outIndex2: number = {}, 0
	local outRequestQueue: { [string]: {any} }, outRequestIndex: number = {}, 0
	local throwRequest: { [string]: {any} }, throwIndex: number = {}, 0
	RunService.PostSimulation:Connect(function()
		-- Sent queues to server
		if outIndex2 > 0 then
			outIndex2 = 0
			UnreliableEvent:FireServer(outQueue2)
			table.clear(outQueue2)
		end
		if outIndex > 0 then
			outIndex = 0
			Event:FireServer(outQueue)
			table.clear(outQueue)
		end
		if outRequestIndex > 0 then
			outRequestIndex = 0
			Event:FireServer("0", outRequestQueue)
			table.clear(outRequestQueue)
		end
		if throwIndex > 0 then
			throwIndex = 0
			Event:FireServer("1", throwRequest)
			table.clear(throwRequest)
		end
		debug.profilebegin("FastNet2.process")
		for Identifier: string, net in Collections do
			if net._pre_f then
				if #net._pre > 0 then
					for _, data in net._pre do
						for _, x in data do
							FastSpawn(net._pre_f, table.unpack(x))
						end
					end
					table.clear(net._pre)
				end
				if #net._pre_p > 0 then
					for _, data in net._pre_p do
						for i, x in data do
							FastSpawn(ClientProcess.pushback, Identifier, i, net._pre_f(table.unpack(x)))
						end
						table.clear(data)
					end
				end
			end
			-- Packet to Queue
			if #Outgoing[Identifier] > 0 then
				if #Outgoing[Identifier] > ClientProcess.processLimit then
					if not outQueue[Identifier] then
						outQueue[Identifier] = {}
					end
					if not outQueue2[Identifier] then
						outQueue2[Identifier] = {}
					end
					if (os.clock() - net._rate) >= ClientProcess.igroneOnLimit then
						net._rate = os.clock()
						for i=1,ClientProcess.processLimit do
							if net.reliable then
								outQueue[Identifier][i] = Outgoing[Identifier][i]
							else
								outQueue2[Identifier][i] = Outgoing[Identifier][i]
							end
							net.OutgoingOrder -= 1
							table.remove(Outgoing[Identifier], i)
						end
						if net.reliable then
							if #outQueue[Identifier] > 0 then
								outIndex += 1
							end
						else
							if #outQueue2[Identifier] > 0 then
								outIndex2 += 1
							end
						end
					end
				else
					if net.reliable then
						outQueue[Identifier] = Outgoing[Identifier]
						outIndex += 1
					else
						outQueue2[Identifier] = Outgoing[Identifier]
						outIndex2 += 1
					end
					net.OutgoingOrder = 0
					Outgoing[Identifier] = {}
				end
			end
			-- Request to Queue
			if net.req_i > 0 then
				outRequestQueue[Identifier] = net.requests
				net.req_i = 0
				outRequestIndex += 1
				net.requests = {}
			end
			-- Return Requests
			if net.re_req_i > 0 then
				throwRequest[Identifier] = net.returnRequest
				net.re_req_i = 0
				throwIndex += 1
				net.returnRequest = {}
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
	if Players.LocalPlayer and not script.Parent.Parent:WaitForChild("Event"):GetAttribute(Players.LocalPlayer.Name) then
		Event:FireServer("2", Players.LocalPlayer.Name)
	end
end

return table.freeze(ClientProcess) :: typeof(ClientProcess)