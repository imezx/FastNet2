-- FastSpawn & FreeThreads
--!strict
local Threads = {}

local function passer(run, ...: any)
	run(...)
end

local function runner(thread)
	while true do
		passer(coroutine.yield())
		if #Threads > 0 and not Threads[#Threads] then
			Threads[#Threads] = thread
		else
			Threads[#Threads + 1] = thread
		end
	end
end

-- Multi-Thread (create 250 threads for multi-threading ready)
for i=1,250 do
	Threads[i] = coroutine.create(runner)
	coroutine.resume(Threads[i], Threads[i])
end

return function<T...>(func: (T...) -> (), ...: T...)
	local thread: any
	if #Threads > 0 and Threads[#Threads] then
		thread = Threads[#Threads]
		Threads[#Threads] = nil
	else
		thread = coroutine.create(runner)
		coroutine.resume(thread, thread)
	end
	task.spawn(thread, func, ...)
	thread = nil
end