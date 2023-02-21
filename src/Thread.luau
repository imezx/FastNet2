--[[
MIT License

Copyright (c) 2022 Someone-dQw4w9WgXcQ

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--!strict
local ThreadPool = {}
local threadIndex: number = 0
local function passer(toRun, ...)
	toRun(...)
end

function ThreadPool.__start(indexs: number) -- How many threads to pre-allocate
	debug.profilebegin("FastNet2.thread.create")
	threadIndex = indexs
	local threads = table.create(threadIndex)

	local function runner(thread: thread): never
		while true do
			-- Run the function
			passer(coroutine.yield())

			-- Done, make this thread available
			threadIndex += 1
			threads[threadIndex] = thread
		end
	end

	for i = 1, threadIndex do
		local thread = coroutine.create(runner)
		coroutine.resume(thread, thread)
		threads[i] = thread
	end
	debug.profileend()

	return function<_, params>(func: (params) -> (), ...: params): (thread)
		-- Xthread 1.0 Feature (free brute-threading)
		if threadIndex < 25 or threadIndex <= 0 then
			debug.profilebegin("FastNet2.thread.freeThread")
			threadIndex = 0
			for i=1,5 do
				local thread = coroutine.create(runner)
				coroutine.resume(thread, thread)
				threads[threadIndex+1] = thread
				threadIndex += 1
			end
			debug.profileend()
		end
		if threadIndex ~= 0 then
			-- Thread available
			local thread = threads[threadIndex]

			-- Remove as available
			threads[threadIndex] = nil
			threadIndex -= 1

			return task.spawn(thread, func, ...)
		else
			local thread = coroutine.create(runner)
			coroutine.resume(thread, thread)

			return task.spawn(thread, func, ...)
		end
	end
end

return table.freeze(ThreadPool)