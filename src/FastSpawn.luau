-- FastSpawn & FreeThreads
local Threads = {}

local function passer(run, ...)
	run(...)
end

local function runner(thread): never
	while true do
		passer(coroutine.yield())
		if #Threads > 0 and not Threads[#Threads] then
			Threads[#Threads] = thread
		else
			Threads[#Threads + 1] = thread
		end
	end
end

-- Multi-Thread (create 25 threads)
for i=1, 50 do
	Threads[i] = coroutine.create(runner)
	coroutine.resume(Threads[i], Threads[i])
end

return function<_, params>(func: (params) -> (), ...: params): never
	local thread
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