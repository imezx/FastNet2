--!strict
local _ableDebug:boolean = true
local levels: any = {
	[1] = print,
	[2] = warn,
	[3] = error,
}

function set_debug(x : boolean)
	if typeof(x) == "boolean" then
		_ableDebug = x
	end
end

function direct_debug(c: any, m: string, l: number, l2: number | nil): boolean
	if _ableDebug then
		local lv: any = l or 2
		lv = levels[lv] or levels[2]
		if lv == 3 then
			if not (c) then lv(m, l2 or 2) elseif (c) == false then lv(m, l2 or 2) end
		else
			if not (c) then lv(m) elseif (c) == false then lv(m) end
		end
	end
	return (c)
end

return {
	__direct_debug = direct_debug,
	set_debug = set_debug
}