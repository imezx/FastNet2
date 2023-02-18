--!strict
local RunService = game:GetService("RunService")
local _ableDebug:boolean = true
local debugsCache: any = {}
local levels: any = {
	[1] = print,
	[2] = warn,
	[3] = error,
}

local _p = tick()
local ranges = 0
RunService.PostSimulation:Connect(function()
	if (tick() - _p) >= 1 then
		ranges = 0
		for i,v in debugsCache do
			ranges += 1
		end
		if ranges > 500 then
			table.clear(debugsCache)
		end
		_p = tick()
	end
end)

function set_debug(x : boolean)
	if typeof(x) == "boolean" then
		_ableDebug = x
	end
end

function get_debugs_inrange(range: number): any
	if not _ableDebug then
		if range == nil or typeof(range) ~= "number" then
			range = 100
		elseif typeof(range) == "number" and range > 500 then
			range = 100
		end
		local toReturn = {}
		for i,v in debugsCache do
			if #toReturn >= range then
				break
			end
			table.insert(toReturn, v)
		end
		return toReturn
	end
	return {}
end

function direct_debug(c: any, m: string, l: number, l2: number?): boolean
	if _ableDebug then
		local lv: any = l or 2
		lv = levels[lv] or levels[2]
		if lv == 3 then
			if not (c) then lv(m, l2 or 2) elseif (c) == false then lv(m, l2 or 2) end
		else
			if not (c) then lv(m) elseif (c) == false then lv(m) end
		end
	else
		table.insert(debugsCache, {c, m, l, l2})
	end
	return (c)
end

return {
	__direct_debug = direct_debug,
	set_debug = set_debug,
	get_debugs_inrange = get_debugs_inrange
}