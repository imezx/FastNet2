-- Author: @EternityDev (Eternity_Devs)
-- oneSignal Module (a custom signal module)
-- (https://github.com/imezx/oneSignal/blob/main/oneSignal.luau)

local oneSignal = {}
oneSignal.ClassName = "oneSignal"
oneSignal.__index = oneSignal

local HttpService = game:GetService("HttpService")
local Collections = {}

local Debug = require(script.Parent.Debug)

function oneSignal.new(identifier: string)
	Debug.new(typeof(identifier) == "string", "[oneSignal]: Identifier must be string")
	Debug.new(not Collections[identifier], string.format("[oneSignal]: %s already exist", identifier))
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
	Debug.new(Collections[identifier], string.format("[oneSignal]: %s not exist", identifier))
	return Collections[identifier]
end

function oneSignal:Connect(callback: (...any) -> ())
	if self then
		Debug.new(not self.Connected, string.format("[oneSignal]: %s already connected", self.Identifier))
		self.cb = callback
		self.Connected = true
	end
end

function oneSignal:Invoke(timeout: number, ...: any): any
	if self then
		timeout = math.max(1, timeout)
		local thread, packed, retrive = coroutine.running(), { ... }, nil
		local session = task.delay(timeout, function()
			task.cancel(retrive)
			task.spawn(thread, nil)
			packed = nil
		end)
		retrive = task.spawn(function()
			task.wait(1/60)
			task.cancel(session)
			task.spawn(thread, self.cb(table.unpack(packed)))
			packed = nil
		end)
		return coroutine.yield()
	end
end

function oneSignal:Wait(): number
	if self then
		local thread = coroutine.running()
		local clock = os.clock()
		self._ping = function(x)
			self._ping = nil
			task.spawn(thread, (x - clock))
		end
		return coroutine.yield()
	end
end

function oneSignal:Once(callback: (...any) -> ())
	if self and not self.Connected then
		self.cb = function(...)
			self:Disconnect()
			task.spawn(callback, ...)
		end
		self.Connected = true
	end
end

function oneSignal:Disconnect()
	if self and self.Connected then
		self.Connected = false
		self.cb = nil
	end
end

function oneSignal:Destroy()
	self:Disconnect()
	if self then
		Collections[self.Identifier] = nil
		self = nil
	end
end

function oneSignal:Fire(...: any)
	if self then
		if self.Connected then
			task.spawn(self.cb, ...)
		end
		if self._ping then
			task.spawn(self._ping, os.clock())
		end
	end
end

return table.freeze(oneSignal)