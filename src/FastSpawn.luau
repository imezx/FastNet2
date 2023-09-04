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
	if Threads[#Threads] then
		task.spawn(Threads[#Threads], func, ...)
		Threads[#Threads] = nil
	else
		local thread: any = coroutine.create(runner)
		coroutine.resume(thread, thread)
		task.spawn(thread, func, ...)
		thread = nil
	end
end