local api = robot.internal_api

-- Safe LUA execution, stolen from mesecons/mesecons_luacontroller/init.lua

-------------------------
-- Parsing and running --
-------------------------

local function safe_print(param)
	local string_meta = getmetatable("")
	local sandbox = string_meta.__index
	string_meta.__index = string -- Leave string sandbox temporarily
	print(dump(param))
	string_meta.__index = sandbox -- Restore string sandbox
end

local function safe_date()
	return(os.date("*t",os.time()))
end

-- string.rep(str, n) with a high value for n can be used to DoS
-- the server. Therefore, limit max. length of generated string.
local function safe_string_rep(str, n)
	--TODO: settings
	local string_rep_max = 64000--mesecon.setting("luacontroller_string_rep_max", 64000)
	if #str * n > string_rep_max then
		debug.sethook() -- Clear hook
		error("string.rep: string length overflow", 2)
	end

	return string.rep(str, n)
end

-- string.find with a pattern can be used to DoS the server.
-- Therefore, limit string.find to patternless matching.
local function safe_string_find(...)
	if (select(4, ...)) ~= true then
		debug.sethook() -- Clear hook
		error("string.find: 'plain' (fourth parameter) must always be true in a Luacontroller")
	end

	return string.find(...)
end

local function remove_functions(xarg)
	local tp = type(xarg)
	if tp == "function" then
		return nil
	end

	-- Make sure to not serialize the same table multiple times, otherwise
	-- writing mem.test = mem in the Luacontroller will lead to infinite recursion
	local seen = {}

	local function rfuncs(x)
		if x == nil then return end
		if seen[x] then return end
		seen[x] = true
		if type(x) ~= "table" then return end

		for key, value in pairs(x) do
			if type(key) == "function" or type(value) == "function" then
				x[key] = nil
			else
				if type(key) == "table" then
					rfuncs(key)
				end
				if type(value) == "table" then
					rfuncs(value)
				end
			end
		end
	end

	rfuncs(xarg)

	return xarg
end

local safe_globals = {
	-- Don't add pcall/xpcall unless willing to deal with the consequences (unless very careful, incredibly likely to allow killing server indirectly)
	"assert", "error", "ipairs", "next", "pairs", "select",
	"tonumber", "tostring", "type", "unpack", "_VERSION"
}

local function create_environment(pos, mem, commands, send_warning)
	-- Gather variables for the environment

	-- Create new library tables on each call to prevent one Luacontroller
	-- from breaking a library and messing up other Luacontrollers.
	local env = {
		mem = mem,
		print = safe_print,
		string = {
			byte = string.byte,
			char = string.char,
			format = string.format,
			len = string.len,
			lower = string.lower,
			upper = string.upper,
			rep = safe_string_rep,
			reverse = string.reverse,
			sub = string.sub,
			find = safe_string_find,
		},
		math = {
			abs = math.abs,
			acos = math.acos,
			asin = math.asin,
			atan = math.atan,
			atan2 = math.atan2,
			ceil = math.ceil,
			cos = math.cos,
			cosh = math.cosh,
			deg = math.deg,
			exp = math.exp,
			floor = math.floor,
			fmod = math.fmod,
			frexp = math.frexp,
			huge = math.huge,
			ldexp = math.ldexp,
			log = math.log,
			log10 = math.log10,
			max = math.max,
			min = math.min,
			modf = math.modf,
			pi = math.pi,
			pow = math.pow,
			rad = math.rad,
			random = math.random,
			sin = math.sin,
			sinh = math.sinh,
			sqrt = math.sqrt,
			tan = math.tan,
			tanh = math.tanh,
		},
		table = {
			concat = table.concat,
			insert = table.insert,
			maxn = table.maxn,
			remove = table.remove,
			sort = table.sort,
		},
		os = {
			clock = os.clock,
			difftime = os.difftime,
			time = os.time,
			datetable = safe_date,
		},
		robot = commands
	}
	env._G = env

	for _, name in pairs(safe_globals) do
		env[name] = _G[name]
	end

	return env
end


local function timeout()
	debug.sethook() -- Clear hook
	error("Code timed out!", 2)
end


local function create_sandbox(code, env)
	if code:byte(1) == 27 then
		return nil, "Binary code prohibited."
	end
	local f, msg = loadstring(code)
	if not f then return nil, msg end
	setfenv(f, env)

	-- Turn off JIT optimization for user code so that count
	-- events are generated when adding debug hooks
	if rawget(_G, "jit") then
		jit.off(f, true)
	end

	-- TODO: settings
	local maxevents = 999999999--10000--mesecon.setting("luacontroller_maxevents", 10000)
	return function(...)
		-- NOTE: This runs within string metatable sandbox, so the setting's been moved out for safety
		-- Use instruction counter to stop execution
		-- after luacontroller_maxevents
		debug.sethook(timeout, "", maxevents)
		local ok, ret = pcall(f, ...)
		debug.sethook()  -- Clear hook
		if not ok then error(ret, 0) end
		return ret
	end
end


local function load_memory(nodeinfo)
	local meta = nodeinfo.meta()
	return minetest.deserialize(meta:get_string("memory"), true) or {}
end


local function save_memory(nodeinfo, mem)
	local memstring = minetest.serialize(remove_functions(mem))
	-- TODO: settings
	local memsize_max = 100000--mesecon.setting("luacontroller_memsize", 100000)

	if (#memstring <= memsize_max) then
		local meta = nodeinfo.meta()
		meta:set_string("memory", memstring)
		meta:mark_as_private("memory")
	else
		print("Error: Luacontroller memory overflow. "..memsize_max.." bytes available, "
				..#memstring.." required. Controller overheats.")
		-- TODO: break or error?
	end
end

local function runtime_ability(nodeinfo, action)
	local ran = false
	local result
	return function (...)
		if ran then
			return result
		end
		ran = true
		result = action(nodeinfo, ...)
		return result
	end
end

-- Returns success (boolean), errmsg (string)
-- run (as opposed to run_inner) is responsible for setting up meta according to this output
local function run_inner(nodeinfo)

	-- Load code & mem from meta
	local mem  = load_memory(nodeinfo)
	local meta = nodeinfo.meta()
	local code = meta:get_string("code")
	local pos = nodeinfo.pos()

	-- 'Last warning' label.
	local warning = ""
	local function send_warning(str)
		warning = "Warning: " .. str
	end

	-- Create environment

	local commands = {}
	local action_call = nil

	for _,ability in ipairs(api.abilities) do
		if ability.action then
			if not api.has_ability(nodeinfo, ability.ability) then
				commands[ability.ability] = function ()
					error(api.translations.cant.." "..ability.ability..": "..api.translations.noability, 2)
				end
			elseif ability.runtime then
				commands[ability.ability] = runtime_ability(nodeinfo, ability.action)
			else
				commands[ability.ability] = function (...)
					if action_call then
						error(api.translations.cant.." "..ability.ability..": "..api.translations.onlyone, 2)
						return
					end
					action_call = {
						ability = ability.ability,
						args = {...}
					}
				end
			end
		end
	end
	commands.stop = function ()
		if action_call then
			error(api.translations.cant.." stop: "..api.translations.onlyone, 2)
			return
		end
		action_call = {
			ability = "stop",
			args = {}
		}
	end
	local logs = {}
	-- commands.log = function (...)
	-- 	local lg = {}
	-- 	for i,v in ipairs({...}) do
	-- 		if type(v) == 'table' then
	-- 			table.insert(lg, table.copy(v))
	-- 		else
	-- 			table.insert(lg, v)
	-- 		end
	-- 	end
	-- 	table.insert(logs, lg)
	-- end

	local env = create_environment(pos, mem, commands, send_warning)

	-- Create the sandbox and execute code
	local sandbox_success, sandbox_msg = create_sandbox(code, env)
	if not sandbox_success then return false, sandbox_msg end
	-- Start string true sandboxing
	local onetruestring = getmetatable("")
	-- If a string sandbox is already up yet inconsistent, something is very wrong
	assert(onetruestring.__index == string)
	onetruestring.__index = env.string
	local run_success, run_msg = pcall(sandbox_success)
	onetruestring.__index = string
	-- End string true sandboxing
	if not run_success then return false, run_msg end

	-- Save memory. This may burn the luacontroller if a memory overflow occurs.
	save_memory(nodeinfo, env.mem)

	-- if #logs then
	-- 	for i,l in ipairs(logs) do
	-- 		minetest.log("error", dump(l))
	-- 	end
	-- end

	if action_call then
		local action_func
		if action_call.ability == 'stop' then
			action_func = api.stop_action
		elseif action_call.ability == 'log' then
			action_func = api.log_action
		else
			local ability_obj = api.abilities_ability_index[action_call.ability]
			action_func = ability_obj.action
		end

		local action_success, newinfo_or_err, fuel_used = pcall(action_func, nodeinfo, unpack(action_call.args))

		if not action_success then
			return false, api.translations.cant.." "..action_call.ability..": "..newinfo_or_err
		end

		return true, warning, newinfo_or_err, fuel_used or 1
	end
	return true, warning
end

api.execute = run_inner
