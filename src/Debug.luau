--!strict
local silentDebug: boolean = true
local debugsCache: any = {}
local levels: any = {
	[1] = print,
	[2] = warn,
	[3] = error,
}

function _gosilent(x : boolean)
	if typeof(x) == "boolean" then
		silentDebug = x
	end
end

function get_log(sName: string?): any
	if silentDebug then
		if sName and typeof(sName) == "string" then
			return debugsCache[sName] or {}
		end
		return debugsCache
	end
	return {}
end

function direct_debug(c: any, m: string, l: number, l2: number?, l3: string?): boolean
	if not silentDebug then
		local lv: any = levels[lv] or levels[2]
		if lv == 3 then
			if not (c) then lv(m, l2 or 2) elseif (c) == false then lv(m, l2 or 2) end
		else
			if not (c) then lv(m) elseif (c) == false then lv(m) end
		end
	else
		if typeof(l3) ~= "string" then
			if not debugsCache["INTERNAL"] then
				debugsCache["INTERNAL"] = {}
			end
			table.insert(debugsCache["INTERNAL"], m)
		elseif l3 and tostring(l3):len() > 0 then
			if not debugsCache[l3] then
				debugsCache[l3] = {}
			end
			table.insert(debugsCache[l3], m)
		end
	end
	return (c)
end

return table.freeze({
	__direct_debug = direct_debug,
	silentDebug = _gosilent,
	get_log = get_log
})
