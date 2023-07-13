-- FastSpawn &nFreeThreads
local threadIndex = 25
local Threads = table.create(threadIndex)

local function passer(run, ...)
	run(...)
end

local function runner(thread: thread): never
	while true do
		passer(coroutine.yield())
		Threads[#Threads + 1] = thread
	end
end

for i = 1, threadIndex do
	Threads[i] = coroutine.create(runner)
	coroutine.resume(Threads[i])
end

return function<_, params>(func: (params) -> (), ...: params): never
	local thread
	if threadIndex > 0 and Threads[#Threads] then
		thread = Threads[#Threads]
		Threads[#Threads] = nil
	else
		thread = coroutine.create(runner)
		coroutine.resume(thread)
	end
	task.spawn(thread, func, ...)
end
