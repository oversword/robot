
local S = minetest.get_translator("robot")

local fuel_item = 'default:coal_lump'
if minetest.get_modpath('tubelib_addons1') then
	fuel_item = 'tubelib_addons1:biofuel'
end

local ability_item = 'default:skeleton_key'

local repair_item = 'default:mese_crystal'
if minetest.get_modpath('tubelib') then
	repair_item = 'tubelib:repairkit'
end

-- TODO: settings
local max_push = 1--mesecon.setting("movestone_max_push", 50)
local step_delay = 2
local max_fall = 10

robot = {}

local api = {}

local abilities = {}
api.abilities_item_index = {}
api.abilities_ability_index = {}

function robot.add_ability(ability_obj)
	local existing_ability_obj = api.abilities_ability_index[ability_obj.ability]
	if existing_ability_obj then
		minetest.log("warning", ("[robot] overriding %s ability"):format(ability_obj.ability))
	end
	local existing_item_ability = api.abilities_item_index[ability_obj.item]
	if existing_item_ability and existing_item_ability.ability ~= ability_obj.ability then
		error(("An ability already exists for this item: '%s'."):format(ability_obj.item))
		return
	end
	if not ability_obj.ability then
		error("You must define an ability name as ability_obj.ability")
		return
	end
	if not ability_obj.item then
		error("You must define an ability item as ability_obj.item")
		return
	end
	if not ability_obj.description then
		error("You must define an ability description as ability_obj.description")
		return
	end
	if existing_ability_obj then
		local new_abilities = {}
		for _,ability in ipairs(abilities) do
			if ability.ability == ability_obj.ability then
				table.insert(new_abilities, ability_obj)
			else
				table.insert(new_abilities, ability)
			end
		end
		abilities = new_abilities
	else
		table.insert(abilities, ability_obj)
	end
	api.abilities_item_index[ability_obj.item] = ability_obj
	api.abilities_ability_index[ability_obj.ability] = ability_obj
end

function robot.set_ability_item(ability, item)
	local ability_obj = api.abilities_ability_index[ability]
	if not ability_obj then
		error("Cannot set the item of an ability that does not exist.")
		return
	end
	local existing_item_ability = api.abilities_item_index[item]
	if existing_item_ability then
		error(("An ability already exists for this item: '%s'."):format(item))
		return
	end
	api.abilities_item_index[ability_obj.item] = nil
	api.abilities_item_index[item] = ability_obj
	ability_obj.item = item
end



local turn_ability_item
if minetest.get_modpath('rhotator') then
	turn_ability_item = 'rhotator:screwdriver'
elseif minetest.get_modpath('screwdriver') then
	turn_ability_item = 'screwdriver:screwdriver'
end
if turn_ability_item then
	robot.add_ability({
		ability = 'turn',
		item = turn_ability_item,
		description = S("Rotate the robot 90 degrees"),
		command_example = "robot.rotate(<anticlockwise? true|false/nil>)",
		action = function (pos, anticlockwise)
			local node = minetest.get_node(pos)
			if anticlockwise then
				node.param2 = (node.param2-1)%4
			else
				node.param2 = (node.param2+1)%4
			end
			minetest.swap_node(pos, node)
		end
	})
end


local move_ability_item
if minetest.get_modpath('carts') then
	move_ability_item = "carts:cart"
end
if move_ability_item then
	robot.add_ability({
		ability = "move",
		item = move_ability_item,
		description = S("Move one block forwards"),
		action = function (pos)
			local node = minetest.get_node(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local meta = minetest.get_meta(pos)

			local owner = meta:get_string('player_name')
			if api.has_ability(meta, nil, 'push') then
				-- ### Step 1: Push nodes in front ###
				local success, stack, oldstack = mesecon.mvps_push(frontpos, direction, max_push, owner)
				if not success then
					if stack == "protected" then
						error("protected area in the way", 2)
						return
					end
					error("blocked", 2)
					return
				end
				mesecon.mvps_move_objects(frontpos, direction, oldstack)
			elseif minetest.is_protected(frontpos, owner) then
				error("protected area in the way", 2)
				return
			elseif not api.can_move_to(frontpos) then
				error("blocked", 2)
				return
			end

			-- ### Step 2: Move the movestone ###
			api.move_robot(node, meta, pos, frontpos)

			-- ### Step 4: Let things fall ###
			minetest.check_for_falling(vector.add(pos, {x=0, y=1, z=0}))

			return frontpos
		end
	})
end


local climb_ability_item
if minetest.get_modpath('mesecons_pistons') then
	climb_ability_item = 'mesecons_pistons:piston_normal_off'
end
if climb_ability_item then
	robot.add_ability({
		ability = 'climb',
		item = climb_ability_item,
		description = S("Climb up and forwards one block"),
		action = function (pos)
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)
			local uppos = vector.add(frontpos, {x=0,y=1,z=0})

			local owner = meta:get_string('player_name')
			if minetest.is_protected(uppos, owner) then
				error("protected area in the way", 2)
				return
			elseif not api.can_move_to(uppos) then
				error("blocked", 2)
				return
			end

			local under_node = minetest.get_node(frontpos)
			local under_node_def  = minetest.registered_nodes[under_node.name]
			if not under_node_def.walkable then
				error("no support", 2)
				return
			end

			-- TODO: ray trace to make sure the hitbox isn't blocking?
			api.move_robot(node, meta, pos, uppos)

			return uppos
		end
	})
end


local look_ability_item
if minetest.get_modpath('mesecons_detector') then
	look_ability_item = 'mesecons_detector:node_detector_off'
elseif minetest.get_modpath('binoculars') then
	look_ability_item = "binoculars:binoculars"
end
if look_ability_item then
	robot.add_ability({
		ability = "look",
		item = look_ability_item,
		description = S("Get the name of the node in front of the robot"),
		command_example = "node_name = robot.look()",
		action = function (pos)
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local front_node = minetest.get_node(frontpos)

			return front_node.name
		end,
		runtime = true
	})
end

if minetest.get_modpath('dispenser') then
	robot.add_ability({
		ability = 'place',
		item = 'dispenser:dispenser',
		description = S("Place a block down"),
		command_example = "robot.place(<dir 'up'|'front'/nil|'down'>)",
		action = function (pos, dir)
			if not dir then dir = 'front' end

			if type(dir) ~= 'string' then
				error('placing dir must be a string',2)
				return
			end
			if not (dir == 'up' or dir == 'front' or dir == 'down') then
				error(("direction '%s' is invalid"):format(dir), 2)
				return
			end

			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()

			local direction
			if dir == 'front' then
				direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			elseif dir == 'up' then
				direction = {x=0,y=1,z=0}
			elseif dir == 'down' then
				if not api.abilities_ability_index.climb
				  or not inv:contains_item('abilities', api.abilities_ability_index.climb.item)
				then
					error('requires climb ability to place block below', 2)
					return
				end
				direction = {x=0,y=0,z=0}
			end
			local owner = meta:get_string('player_name')
			local frontpos = vector.add(pos, direction)
			if minetest.is_protected(frontpos, owner) then
				error("protected area in the way", 2)
				return
			end

			local list = inv:get_list('main')
			local next_stack
			local next_index
			for index,stack in ipairs(list) do
				if not stack:is_empty() then
					next_stack = stack
					next_index = index
					break
				end
			end
			if not next_stack then
				error("inventory empty", 2)
				return
			end
			local item_name = next_stack:get_name()
			local def = minetest.registered_items[item_name]
			if not (def and def.on_place) then
				error("item not placable", 2)
				return
			end
			local player_opts = {
				front = frontpos,
				dir = direction,
				pos = pos,
				meta = meta,
				index = next_index
			}

			local new_pos
			local fuel_used
			if dir == 'down' then
				local uppos = vector.add(pos, {x=0,y=1,z=0})
				if minetest.is_protected(uppos, owner) then
					error("protected area in the way", 2)
					return
				elseif not api.can_move_to(uppos) then
					error("blocked", 2)
					return
				end
				player_opts.meta = api.move_robot(node, meta, pos, uppos)
				player_opts.pos = uppos
				player_opts.dir = {x=0,y=-1,z=0}
				inv = player_opts.meta:get_inventory()
				next_stack = inv:get_stack('main', next_index)

				new_pos = uppos
				fuel_used = 2

			end
			local player = dispenser.actions.fake_player(next_stack, player_opts)
			if not player then
				error("player not logged in", 2)
				return
			end

			local result, placed_pos = def.on_place(next_stack, player, {
				type="node",
				under=frontpos,
				above=frontpos
			})
			minetest.check_for_falling(frontpos)
			if result then
				inv:set_stack('main', next_index, result)
			end
			return new_pos, fuel_used
		end
	})
end


local use_ability_item
if minetest.get_modpath('bones') then
	use_ability_item = "bones:bones"
end
if use_ability_item and minetest.get_modpath('dispenser') then
	robot.add_ability({
		ability = "use",
		item = use_ability_item,
		description = S("Use an item (not a tool)"),
		action = function (pos)
			local node = minetest.get_node(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local list = inv:get_list('main')
			local next_stack
			local next_index
			for index,stack in ipairs(list) do
				if not stack:is_empty() then
					next_stack = stack
					next_index = index
					break
				end
			end
			if not next_stack then
				error("inventory empty", 2)
				return
			end

			local item_name = next_stack:get_name()
			local def = minetest.registered_items[item_name]
			if not (def and def.on_use) then
				error("item not usable", 2)
				return
			end
			local player = dispenser.actions.fake_player(next_stack, {
				front = frontpos,
				dir = direction,
				pos = pos,
				meta = meta,
				index = next_index
			})
			if not player then
				error("player not logged in", 2)
				return
			end
			local result = def.on_use(next_stack, player, {
				type="node",
				under=frontpos,
				above=vector.add(frontpos, {x=0,y=1,z=0})
			})
			if result then
				inv:set_stack('main', next_index, result)
			end
		end
	})
end


local push_ability_item
if minetest.get_modpath('mesecons_movestones') then
	push_ability_item = "mesecons_movestones:movestone"
end
if push_ability_item and minetest.get_modpath('mesecons_mvps') then
	robot.add_ability({
		ability = 'push',
		item = push_ability_item,
		description = S("Push a block when moving forwards")
	})
end


local carry_ability_item
if minetest.get_modpath('hook') then
	carry_ability_item = 'hook:pchest'
elseif minetest.get_modpath('unified_inventory') then
	carry_ability_item = 'unified_inventory:bag_large'
elseif minetest.get_modpath('default') then
	carry_ability_item = 'default:chest'
end
if carry_ability_item then
	robot.add_ability({
		ability = "carry",
		item = carry_ability_item,
		description = S("Expand the item inventory"),
		modifier = function(pos, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size('main', 16)
		end,
		un_modifier = function(pos, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()

			-- Spit out any extra items
			local list = inv:get_list('main')
			for i,stack in ipairs(list) do
				if i > 1 then
					minetest.add_item(vector.add(pos, {x=0,y=0.5,z=0}), stack)
				end
			end

			inv:set_size('main', 1)
		end,
	})
end


local fuel_ability_item
if minetest.get_modpath('unified_inventory') then
	fuel_ability_item = 'unified_inventory:bag_small'
elseif minetest.get_modpath('default') then
	fuel_ability_item = 'default:furnace'
end
if fuel_ability_item then
	robot.add_ability({
		ability = "fuel",
		item = fuel_ability_item,
		description = S("Expand the fuel inventory"),
		modifier = function(pos, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size('fuel', 4)
			api.update_formspec(pos, meta)

			if api.formspec_data[player_name]
				and api.formspec_data[player_name].psuedo_metadata
			then
				api.update_formspec(pos, meta)
				minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
			end
		end,
		un_modifier = function(pos, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()

			-- Spit out any extra items
			local list = inv:get_list('fuel')
			for i,stack in ipairs(list) do
				if i > 1 then
					minetest.add_item(vector.add(pos, {x=0,y=0.5,z=0}), stack)
				end
			end

			inv:set_size('fuel', 1)
			api.update_formspec(pos, meta)

			if api.formspec_data[player_name]
				and api.formspec_data[player_name].psuedo_metadata
			then
				api.update_formspec(pos, meta)
				minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
			end
		end,
	})
end


local fill_ability_item
if minetest.get_modpath('tubelib') then
	fill_ability_item = 'tubelib:tubeS'
end
if fill_ability_item and minetest.get_modpath('tubelib') then
	robot.add_ability({
		ability = 'fill',
		item = fill_ability_item,
		description = S("Fill and empty the inventory using pushers"),
	})
end


local stop_action = function (pos)
	api.set_status(pos, minetest.get_meta(pos), 'stopped')
	return nil, 0
end

function api.stop_timer(pos)
	local timer = minetest.get_node_timer(pos)
	if timer:is_started() then
		timer:stop()
	end
end

function api.start_timer(pos)
	local timer = minetest.get_node_timer(pos)
	if not timer:is_started() then
		timer:start(step_delay)
	end
end

function api.move_robot(node, meta, pos, new_pos)
	minetest.set_node(new_pos, node)
	local meta2 = minetest.get_meta(new_pos)
	meta2:from_table(meta:to_table())
	meta2:set_string('pos', minetest.pos_to_string(new_pos))
	meta2:mark_as_private('code')
	meta2:mark_as_private('memory')
	minetest.remove_node(pos)

	minetest.after(0.01, api.stop_timer, pos)
	-- minetest.sound_play("movestone", { pos = pos, max_hear_distance = 20, gain = 0.5 }, true)
	return meta2
end

function api.can_move_to(pos)
	local node = minetest.get_node(pos)

	if minetest.registered_nodes[node.name] then
		return minetest.registered_nodes[node.name].buildable_to or false
	end

	return false
end

function api.has_ability(meta, inv, ability)
	if not api.abilities_ability_index[ability] then
		return false
	end
	if not inv then
		inv = meta:get_inventory()
	end
	if not inv:contains_item('abilities', api.abilities_ability_index[ability].item) then
		return false
	end
	return true
end

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

local function remove_functions(x)
	local tp = type(x)
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

	rfuncs(x)

	return x
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
	local maxevents = 10000--mesecon.setting("luacontroller_maxevents", 10000)
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


local function load_memory(meta)
	return minetest.deserialize(meta:get_string("memory"), true) or {}
end


local function save_memory(pos, meta, mem)
	local memstring = minetest.serialize(remove_functions(mem))
	-- TODO: settings
	local memsize_max = 100000--mesecon.setting("luacontroller_memsize", 100000)

	if (#memstring <= memsize_max) then
		meta:set_string("memory", memstring)
		meta:mark_as_private("memory")
	else
		print("Error: Luacontroller memory overflow. "..memsize_max.." bytes available, "
				..#memstring.." required. Controller overheats.")
		burn_controller(pos)
	end
end

local function runtime_ability(pos, action)
	local ran = false
	local result
	return function (...)
		if ran then
			return result
		end
		ran = true
		result = action(pos, ...)
		return result
	end
end

-- Returns success (boolean), errmsg (string)
-- run (as opposed to run_inner) is responsible for setting up meta according to this output
local function run_inner(pos, meta)

	-- Load code & mem from meta
	local mem  = load_memory(meta)
	local code = meta:get_string("code")
	local inv = meta:get_inventory()

	-- 'Last warning' label.
	local warning = ""
	local function send_warning(str)
		warning = "Warning: " .. str
	end


	local trans = {
		cant = S("Can't"),
		onlyone = S("can only perform one action at a time"),
		noability = S("robot does not have this ability")
	}

	-- Create environment

	local commands = {}
	local action_call = nil

	for _,ability in ipairs(abilities) do
		if ability.action then
			if not inv:contains_item('abilities', ability.item) then
				commands[ability.ability] = function ()
					error(trans.cant.." "..ability.ability..": "..trans.noability, 2)
				end
			elseif ability.runtime then
				commands[ability.ability] = runtime_ability(pos, ability.action)
			else
				commands[ability.ability] = function (...)
					if action_call then
						error(trans.cant.." "..ability.ability..": "..trans.onlyone, 2)
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
			error(trans.cant.." stop: "..trans.onlyone, 2)
			return
		end
		action_call = {
			ability = "stop",
			args = {}
		}
	end

	local env = create_environment(pos, mem, commands, send_warning)

	-- Create the sandbox and execute code
	local f, msg = create_sandbox(code, env)
	if not f then return false, msg end
	-- Start string true sandboxing
	local onetruestring = getmetatable("")
	-- If a string sandbox is already up yet inconsistent, something is very wrong
	assert(onetruestring.__index == string)
	onetruestring.__index = env.string
	local success, msg = pcall(f)
	onetruestring.__index = string
	-- End string true sandboxing
	if not success then return false, msg end

	-- Save memory. This may burn the luacontroller if a memory overflow occurs.
	save_memory(pos, meta, env.mem)

	if action_call then
		local action_func
		if action_call.ability == 'stop' then
			action_func = stop_action
		else
			local ability_obj = api.abilities_ability_index[action_call.ability]
			action_func = ability_obj.action
		end

		local action_success, new_pos_or_err, fuel_used = pcall(action_func, pos, unpack(action_call.args))

		if not action_success then
			return false, trans.cant.." "..action_call.ability..": "..new_pos_or_err
		end

		return true, warning, new_pos_or_err, fuel_used or 1
	end
	return true, warning
end



function api.update_formspec(pos, meta)
	if not meta then meta = minetest.get_meta(pos) end
	local inv = meta:get_inventory()

	meta:set_string('formspec', api.formspecs.inventory(meta:get_string('status'), inv:get_size('fuel')))

	-- minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
end

function api.set_status(pos, meta, status)
	local node = minetest.get_node(pos)
	if status == 'running' and node.name ~= "robot:robot_running" then
		minetest.swap_node(pos, {name="robot:robot_running",param2=node.param2})
	elseif status == 'error' and node.name ~= "robot:robot_error" then
		minetest.swap_node(pos, {name="robot:robot_error",param2=node.param2})
	elseif status == 'broken' and node.name ~= "robot:robot_broken" then
		minetest.swap_node(pos, {name="robot:robot_broken",param2=node.param2})
	elseif status == 'stopped' and node.name ~= "robot:robot" then
		minetest.swap_node(pos, {name="robot:robot",param2=node.param2})
	end

	if status == 'running' then
		api.start_timer(pos)
	else
		api.stop_timer(pos)
	end

	meta:set_string('status', status)
	api.update_formspec(pos, meta)
end

function api.set_error(pos, meta, error)
	meta:set_string("error", error)
	if meta:get_int('ignore_errors') ~= 1 then
		api.set_status(pos, meta, 'error')
	end
end

api.formspecs = {}

function api.formspecs.program(code, errmsg, ignore_errors)
	return ([[
		size[12,10]
		style_type[label,textarea;font=mono]
		label[0.1,8.3;%s]
		textarea[0.2,0.2;12.2,9.5;code;;%s]
		button[4.75,9;3,1;program;%s]
		checkbox[1,9;ignore_errors;%s;%s]
		button[9,9;3,1;reset_memory;%s]
	]]):format(
		minetest.formspec_escape(errmsg),
		minetest.formspec_escape(code),
		minetest.formspec_escape(S("Save Program")),
		minetest.formspec_escape(S("Ignore errors")),
		ignore_errors and 'true' or 'false',
		minetest.formspec_escape(S("Reset memory"))
	)
end

function api.formspecs.inventory(status, fuel_size)
	local exec_button = ''
	if status == 'stopped' then
		exec_button = minetest.formspec_escape(S("Run"))
	elseif status == 'error' then
		exec_button = minetest.formspec_escape(S("ERROR"))
	elseif status == 'running' then
		exec_button = minetest.formspec_escape(S("Stop"))
	elseif status == 'broken' then
		exec_button = minetest.formspec_escape(S("Broken"))
	end

	local fuel_pos = 2
	if fuel_size == 1 then
		fuel_pos = 3
	end

	return "size[8,8]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		([[
			list[context;main;0,0;8,2;]
			list[context;abilities;3,3;5,1;]
			list[context;fuel;0,%i;2,2;]
			item_image[0,%i;1,1;%s]
			item_image_button[2,3;1,1;%s;ability_reference;]
			tooltip[ability_reference;%s]
			button[4,2;4,1;program_edit;%s]
			button[2,2;2,1;status;%s]
			list[current_player;main;0,4.3;8,4;]
			listring[context;main]
			listring[current_player;main]
		]]):format(
			fuel_pos,fuel_pos,
			fuel_item,
			ability_item,
			minetest.formspec_escape(S("Ability Reference")),
			minetest.formspec_escape(S("Edit Program")),
			exec_button
		)
end

function api.formspecs.ability()
	local entries = ""
	for i,ability in ipairs(abilities) do
		local command = S("No command")
		if ability.action then
			command = S("Command")..": "
			if ability.command_example then
				command = command .. ability.command_example
			else
				command = command .. "robot."..ability.ability.."()"
			end
		end
		entries = entries .. ([[
			item_image[0,%i;1,1;%s]
			label[1,%i;%s]
			label[1,%f;%s]
		]]):format(
			i-1, ability.item,
			i-1, minetest.formspec_escape(ability.description),
			(i-1)+0.4, command
		)
	end
	return ("size[8,%i]"):format(#abilities)..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		entries
end

function api.formspecs.error(error)
	return ([[
		size[12,2]
		label[0.1,0.3;%s]
		button[4.75,1;3,1;dismiss_error;%s]
	]]):format(
		minetest.formspec_escape(error),
		minetest.formspec_escape(S("Dismiss error"))
	)
end

function api.formspecs.broken()
	local item_description = repair_item
	local item_def = minetest.registered_nodes[repair_item] or minetest.registered_items[repair_item]
	if item_def then
		item_description = item_def.description
	end
	return ([[
		size[8,2]
		item_image[0,0;2,2;%s]
		label[2,0.5;%s]
		label[2,1;%s]
	]]):format(
		repair_item,
		minetest.formspec_escape(S("The robot is broken")),
		minetest.formspec_escape(S("Use a").." "..item_description.." "..S("to repair it"))
	)
end

api.formspec_data = {}

local function on_receive_fields(pos, form_name, fields, sender)
	local player_name = sender:get_player_name()
	if fields.quit then
		api.formspec_data[player_name] = nil
		return
	end
	if fields.ability_reference then
		minetest.show_formspec(player_name, 'robot_abilities', api.formspecs.ability())
		return
	end
	if fields.program_edit then
		api.formspec_data[player_name] = api.formspec_data[player_name] or {}
		api.formspec_data[player_name].pos = pos
		local meta = minetest.get_meta(pos)
		local code = meta:get_string('code')
		local err = meta:get_string('error')
		local ignore_errors = meta:get_int('ignore_errors')
		minetest.show_formspec(player_name, 'robot_program', api.formspecs.program(code, err, ignore_errors == 1))
		return
	end
	if fields.status then
		local meta = minetest.get_meta(pos)
		local status = meta:get_string('status')
		if status == 'stopped' then
			meta:set_string('error', '')
			api.set_status(pos, meta, 'running')
			minetest.show_formspec(player_name, '', '')
		elseif status == 'running' then
			api.set_status(pos, meta, 'stopped')
		elseif status == 'error' then
			api.formspec_data[player_name] = api.formspec_data[player_name] or {}
			api.formspec_data[player_name].pos = pos
			minetest.show_formspec(player_name, 'robot_error', api.formspecs.error(meta:get_string('error')))
		elseif status == 'broken' then
			minetest.show_formspec(player_name, 'robot_broken', api.formspecs.broken())
		end
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == 'robot_inventory' then
		local player_name = player:get_player_name()
		local pos = api.formspec_data[player_name].pos
		on_receive_fields(pos, formname, fields, player)
		return
	end
	if formname == 'robot_error' then
		local player_name = player:get_player_name()
		if fields.quit then
			api.formspec_data[player_name] = nil
			return
		end
		if fields.dismiss_error then
			local pos = api.formspec_data[player_name].pos
			local meta = minetest.get_meta(pos)
			if meta:get_string('status') == 'error' then
				meta:set_string('error', '')
				api.set_status(pos, meta, 'stopped')
			end

			api.formspec_data[player_name].psuedo_metadata = true
			minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
		end
		return
	end

	if formname ~= 'robot_program' then return end

	local player_name = player:get_player_name()
	if fields.quit then
		api.formspec_data[player_name] = nil
		return
	end

	local pos = api.formspec_data[player_name].pos
	local meta = minetest.get_meta(pos)

	if fields.ignore_errors then
		if fields.ignore_errors == 'true' then
			meta:set_int('ignore_errors', 1)
		else
			meta:set_int('ignore_errors', 0)
		end
	elseif fields.reset_memory then
		meta:set_string('memory', minetest.serialize({}))
	elseif fields.code then
		meta:set_string('code', fields.code)
		meta:mark_as_private('code')
		if meta:get_string('status') == 'error' then
			api.set_status(pos, meta, 'stopped')
		end

		api.formspec_data[player_name].psuedo_metadata = true
		minetest.show_formspec(player_name, 'robot_inventory', meta:get_string('formspec'))
	end
end)


local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == 'fuel' then
		-- Main stack only accepts fuel
		if stack:get_name() == fuel_item then
			return stack:get_count()
		end
	elseif listname == 'abilities' then
		-- Ability stack only accepts one of each ability item
		local item = stack:get_name()
		if api.abilities_item_index[item] then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if not inv:contains_item(listname, item) then
				return 1
			end
		else
	end
	elseif listname == 'main' then
		return stack:get_count()
	end
	return 0
end
local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end
local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	if from_list == to_list then return count end

	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	local from_stack = inv:get_stack(from_list, from_index)
	from_stack:set_count(count)

	local take_count = allow_metadata_inventory_take(pos, from_list, from_index, from_stack, player)
	if take_count == 0 then return 0 end
	from_stack:set_count(take_count)

	local put_count = allow_metadata_inventory_put(pos, to_list, to_index, from_stack, player)
	if put_count == 0 then return 0 end
	return put_count
end

local function on_metadata_inventory_put(pos, listname, index, stack, player)
	if listname ~= 'abilities' then return end

	local item_name = stack:get_name()
	local ability = api.abilities_item_index[item_name]
	if ability.modifier then
		if not ability.un_modifier then
			minetest.log("error", "[robot] Ability modifier will not run unless it has an un-modfier method.")
			return
		end
		ability.modifier(pos, player:get_player_name())
	end
end
local function on_metadata_inventory_take(pos, listname, index, stack, player)
	if listname ~= 'abilities' then return end

	local item_name = stack:get_name()
	local ability = api.abilities_item_index[item_name]
	if ability.un_modifier then
		ability.un_modifier(pos, player:get_player_name())
	end
end
local function on_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	if from_list == to_list then return end

	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	local to_stack = inv:get_stack(to_list, to_index)
	to_stack:set_count(count)

	on_metadata_inventory_take(pos, from_list, from_index, to_stack, player)
	on_metadata_inventory_put(pos, to_list, to_index, to_stack, player)
end

local function after_dig_node(pos, oldnode, oldmeta_table, player)
	local stack = ItemStack({
		name = oldnode.name == "robot:robot_broken"
			and "robot:robot_broken"
			or "robot:robot",
		count = 1
	})
	local nodedef = stack:get_definition()
	local stackmeta = stack:get_meta()

	stackmeta:set_int('ignore_errors', oldmeta_table.fields.ignore_errors or 0)
	stackmeta:set_string('code', oldmeta_table.fields.code)
	stackmeta:set_string('memory', oldmeta_table.fields.memory)
	local ability_table = {}
	if oldmeta_table.inventory.abilities then
		for _,itemstack in ipairs(oldmeta_table.inventory.abilities) do
			table.insert(ability_table, itemstack:get_name())
		end
	end
	stackmeta:set_string('abilities', minetest.serialize(ability_table))

	-- Drop all items
	if oldmeta_table.inventory.fuel then
		for _,itemstack in ipairs(oldmeta_table.inventory.fuel) do
			minetest.add_item(pos, itemstack)
		end
	end
	if oldmeta_table.inventory.main then
		for _,itemstack in ipairs(oldmeta_table.inventory.main) do
			minetest.add_item(pos, itemstack)
		end
	end

	if not (player and player:is_player()) then
		minetest.add_item(pos, stack)
	else
		local inv = player:get_inventory()
		local leftover = inv:add_item('main', stack)
		if leftover and not leftover:is_empty() then
			minetest.add_item(pos, leftover)
		end
	end
	return false
end

local function after_place_node(pos, player, itemstack)
	local stackmeta = itemstack:get_meta()
	local code = stackmeta:get_string('code')
	local memory = stackmeta:get_string('memory')
	local ability_str = stackmeta:get_string('abilities')
	local ignore_errors = stackmeta:get_int('ignore_errors')

	local meta = minetest.get_meta(pos)
	meta:set_string('code', code)
	meta:set_int('ignore_errors', ignore_errors)
	if memory ~= "" then
		meta:set_string('memory', minetest.deserialize(memory))
	end
	if ability_str ~= "" then
		local ability_table = minetest.deserialize(ability_str)
		local inv = meta:get_inventory()
		for i,item in ipairs(ability_table) do
			if item ~= "" then
				inv:set_stack('abilities', i, item)

				local ability = api.abilities_item_index[item]
				if ability.modifier then
					if not ability.un_modifier then
						minetest.log("error", "[robot] Ability modifier will not run unless it has an un-modfier method.")
						return
					end
					ability.modifier(pos, player:get_player_name())
				end
			end
		end
	end

	meta:mark_as_private("memory")
	meta:mark_as_private('code')

	meta:set_string('player_name', player:get_player_name())
end

local function on_construct(pos)
	local meta = minetest.get_meta(pos)

	meta:set_string('status', 'stopped')
	meta:set_string('code', '')
	meta:set_string('player_name', '??')
	meta:set_string('pos', minetest.pos_to_string(pos))
	meta:set_int('ignore_errors', 0)
	meta:set_string('memory', minetest.serialize({}))

	meta:mark_as_private("memory")
	meta:mark_as_private('code')

	local inv = meta:get_inventory()
	inv:set_size('fuel', 1)
	inv:set_size('main', 1)
	inv:set_size('abilities', 5)

	api.update_formspec(pos, meta)

	-- Need to do this so we can keep running after falling
	api.stop_timer(pos)
	api.start_timer(pos)
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	local meta = minetest.get_meta(pos)
	if meta:get_string('status') == 'running' then
		api.set_status(pos, meta, 'stopped')
	end
end


local function on_timer (pos, dtime)
	local meta = minetest.get_meta(pos)

	if meta:get_string('status') ~= 'running' then
		return false
	end

	local old_pos_str = meta:get_string('pos')
	if old_pos_str ~= "" then
		local old_pos = minetest.string_to_pos(old_pos_str)
		local diff = vector.subtract(old_pos, pos)
		if diff.y > 10 then
			api.set_status(pos, meta, 'broken')
			meta:set_string('error', S("Ouch: internal damage"))
			meta:set_string('pos', minetest.pos_to_string(pos))
			return false
		end
	end

	local inv = meta:get_inventory()

	if inv:is_empty('fuel') then
		api.set_error(pos, meta, S("Out of fuel"))
		return false
	end

	-- If there's no code, stop running but keep the skin
	-- so builders can use the running face
	if meta:get_string('code') == "" then
		inv:remove_item('fuel', fuel_item)
		return false
	end

	local ok, errmsg, new_pos, fuel_used = run_inner(pos, meta)
	if new_pos then
		meta = minetest.get_meta(new_pos)
		inv = meta:get_inventory()
	end
	if fuel_used and fuel_used > 0 then
		inv:remove_item('fuel', ItemStack({ name=fuel_item, count=fuel_used }))
	end

	if not ok then
		-- minetest.log("error",  errmsg)
		api.set_error(new_pos or pos, meta, errmsg)
		return false
	end

	if errmsg ~= "" then
		meta:set_string('error', errmsg)
	end

	return true
end

local basic_props = {
	description = S("Automated Robot"),
	groups = {falling_node = 1, cracky=2},

	buildable_to = false,
	paramtype2 = "facedir",
	is_ground_content = false,
	stack_max = 1,
	drop = '',

	on_construct = on_construct,
	after_place_node = after_place_node,
	on_receive_fields = on_receive_fields,

	on_rightclick = on_rightclick,
	after_dig_node = after_dig_node,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	on_metadata_inventory_put = on_metadata_inventory_put,
	on_metadata_inventory_take = on_metadata_inventory_take,
	on_metadata_inventory_move = on_metadata_inventory_move,
}

if minetest.get_modpath('screwdriver') then
	basic_props.on_rotate = screwdriver.disallow
end

local stopped_props = table.copy(basic_props)
stopped_props.tiles = {
	-- up, down, right, left, back, front
	'robot_top.png',
	'robot_bottom.png',
	'robot_side.png',
	'robot_side.png',
	'robot_back.png',
	'robot_front.png',
}
minetest.register_node("robot:robot", stopped_props)


local running_props = table.copy(basic_props)
running_props.tiles = {
	-- up, down, right, left, back, front
	'robot_top.png',
	'robot_bottom.png',
	{
		name = 'robot_side_running.png',
		animation = {
		type = "vertical_frames",
			aspect_w = 8,
			aspect_h = 8,
			length = 1,
		}
	},
	{
		name = 'robot_side_running.png',
		animation = {
		type = "vertical_frames",
			aspect_w = 8,
			aspect_h = 8,
			length = 1,
		}
	},
	'robot_back_running.png',
	'robot_front_running.png',
}
running_props.groups.not_in_creative_inventory = 1
running_props.on_timer = on_timer
minetest.register_node("robot:robot_running", running_props)


local error_props = table.copy(basic_props)
error_props.tiles = {
	-- up, down, right, left, back, front
	'robot_top.png',
	'robot_bottom.png',
	{
		name = 'robot_side_error.png',
		animation = {
		type = "vertical_frames",
			aspect_w = 8,
			aspect_h = 8,
			length = 1,
		}
	},
	{
		name = 'robot_side_error.png',
		animation = {
		type = "vertical_frames",
			aspect_w = 8,
			aspect_h = 8,
			length = 1,
		}
	},
	'robot_back_error.png',
	'robot_front_error.png',
}
error_props.groups.not_in_creative_inventory = 1
minetest.register_node("robot:robot_error", error_props)


local broken_props = table.copy(basic_props)
broken_props.tiles = {
	-- up, down, right, left, back, front
	'robot_top.png',
	'robot_bottom.png',
	'robot_side_broken.png',
	'robot_side_broken.png',
	'robot_back_error.png',
	'robot_front_broken.png',
}
broken_props.groups.not_in_creative_inventory = 1
broken_props.description = S("Broken Automated Robot")
if repair_item ~= 'tubelib:repairkit' then
	broken_props.on_punch = function (pos, node, puncher, pointed_thing)
		if not (puncher and puncher:is_player()) then return end

		if node.name ~= "robot:robot_broken" then return end

		local item = puncher:get_wielded_item()
		if item:is_empty() then return end
		if item:get_name() ~= repair_item then return end

		local taken = item:take_item(1)
		if taken:is_empty() then return end

		local meta = minetest.get_meta(pos)
		meta:set_string('error', '')
		api.set_status(pos, meta, 'stopped')

		return puncher:set_wielded_item(item)
	end
end
broken_props.after_place_node = function(pos, player, itemstack)
	local meta = minetest.get_meta(pos)
	meta:set_string('status', 'broken')
	return after_place_node(pos, player, itemstack)
end
minetest.register_node("robot:robot_broken", broken_props)

if minetest.global_exists('tubelib') then
	local tubelib_options = {
		on_pull_item = function(pos, side, player_name)
			local meta = minetest.get_meta(pos)
			if api.has_ability(meta, nil, 'fill') then
				return tubelib.get_item(meta, 'main')
			end
			return
		end,
		on_push_item = function(pos, side, item, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if item:get_name() == fuel_item then
				return tubelib.put_item(meta, 'fuel', item)
			elseif api.has_ability(meta, inv, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
		on_unpull_item = function(pos, side, item, player_name)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if api.has_ability(meta, inv, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
	}
	if repair_item == 'tubelib:repairkit' then
		tubelib_options.on_node_repair = function(pos)
			local meta = minetest.get_meta(pos)
			if meta:get_string('status') ~= 'broken' then return end
			meta:set_string('error', '')
			api.set_status(pos, meta, 'stopped')
			return true
		end
	end
	tubelib.register_node(
		"robot:robot",
		{"robot:robot","robot:robot_error","robot:robot_broken","robot:robot_running"},
		tubelib_options
	)
end
