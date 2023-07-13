-- Author: @EternityDev (Eternity_Devs)
-- oneSignal Module (a custom signal module)
-- (https://github.com/imezx/oneSignal/blob/main/oneSignal.luau)

local oneSignal = {}
oneSignal.ClassName = "oneSignal"
oneSignal.__index = oneSignal

local Collections = {}

function oneSignal.new(identifier)
	assert(typeof(identifier) == "string", "[oneSignal]: Identifier must be string")
	assert(not Collections[identifier], string.format("[oneSignal]: %s already exist", identifier))
	Collections[identifier] = setmetatable({
		cb = nil,
		Connected = false,
		Identifier = identifier,
		_ping = nil,
	}, oneSignal)
	return Collections[identifier]
end

function oneSignal.get(identifier)
	assert(Collections[identifier], string.format("[oneSignal]: %s not exist", identifier))
	return Collections[identifier]
end

function oneSignal:Connect(callback)
	if self then
		assert(not self.Connected, string.format("[oneSignal]: %s already connected", self.Identifier))
		self.cb = callback
		self.Connected = true
	end
end

function oneSignal:Wait()
	if self then
		local thread = coroutine.running()
		local clock = os.clock()
		self._ping = function(x)
			task.spawn(thread, x - clock)
			self._ping = nil
		end
		return coroutine.yield()
	end
end

function oneSignal:Once(callback)
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

function oneSignal:Fire(...)
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
