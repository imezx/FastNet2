--!native
-- Author: @EternityDev (Eternity_Devs)
-- oneSignal Module (a custom signal module)
-- (https://github.com/imezx/oneSignal/blob/main/oneSignal.luau)

local oneSignal = {}
oneSignal.ClassName = "Signal"
oneSignal.__index = oneSignal

local Collections = {}

local FastSpawn = require(script.Parent.FastSpawn)
local Debug = require(script.Parent.Debug)

function oneSignal.new(identifier: string)
	Debug.new(typeof(identifier) == "string", "[oneSignal]: Identifier must be string", 0)
	Debug.new(not Collections[identifier], string.format("[oneSignal]: %s already exist", identifier), 0)
	Collections[identifier] = setmetatable({
		cb = nil,
		Connected = false,
		Identifier = identifier,
		_ping = nil,
		invokes = {},
	}, oneSignal)
	return Collections[identifier]
end

function oneSignal.get(identifier: string)
	Debug.new(Collections[identifier], string.format("[oneSignal]: %s not exist", identifier), 0)
	return Collections[identifier]
end

function oneSignal:Connect(callback: (...any) -> ())
	Debug.new(not self.Connected, string.format("[oneSignal]: %s already connected", self.Identifier), 0)
	self.cb = callback
	self.Connected = true
end

function oneSignal:Invoke(timeout: number, ...: any): any
	Debug.new(typeof(timeout) == "number", string.format("[oneSignal]: timeout must be number, got %s", typeof(timeout)), 0)
	Debug.new(#{...} > 0, "[oneSignal]: Unable to invoke without data", 0)
	timeout = math.max(1, timeout)
	local thread, packed, retrive = coroutine.running(), { ... }, nil
	local session = task.delay(timeout, function()
		task.cancel(retrive)
		task.spawn(thread, nil)
		packed = nil
	end)
	retrive = task.defer(function()
		task.spawn(thread, self.cb(table.unpack(packed)))
		task.cancel(session)
		packed = nil
	end)
	return coroutine.yield()
end

function oneSignal:Wait(): number
	local thread, clock = coroutine.running(), os.clock()
	self._ping = function(x)
		self._ping = nil
		task.spawn(thread, (x - clock))
	end
	return coroutine.yield()
end

function oneSignal:Once(callback: (...any) -> ())
	if not self.Connected then
		self:Connect(function(...)
			self:Disconnect()
			task.spawn(callback, ...)
		end)
	end
end

function oneSignal:Disconnect()
	if self.Connected then
		self.Connected = false
		self.cb = nil
	end
end

function oneSignal:Destroy()
	self:Disconnect()
	Collections[self.Identifier] = nil
	setmetatable(self, nil)
end

function oneSignal:Fire(...: any)
	if self.Connected then
		FastSpawn(self.cb, ...)
	end
	if self._ping then
		FastSpawn(self._ping, os.clock())
	end
end

return table.freeze(oneSignal)