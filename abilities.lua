local api = robot.internal_api

local S = api.translator

api.abilities = {}
api.abilities_item_index = {}
api.abilities_ability_index = {}

minetest.register_craftitem(api.config.god_item, {
	description = "God Ability",
	inventory_image = 'robot_god_ability_item.png',
	groups = {
		not_in_creative_inventory = 1
	}
})

function robot.add_ability(ability_obj)
	local existing_item_ability = api.abilities_item_index[ability_obj.item]
	if existing_item_ability and existing_item_ability.ability ~= ability_obj.ability then
		error(("An ability already exists for this item: '%s'."):format(ability_obj.item))
		return
	end
	if not ability_obj.ability then
		error("You must define an ability name as ability_obj.ability")
		return
	end
	if api.parts[ability_obj.ability] then
		error(("Ability cannot be called '%s' as it will conflict with robot.%s.[action] ect."):format(ability_obj.ability))
		return
	end
	if not ability_obj.description then
		error("You must define an ability description as ability_obj.description")
		return
	end
	if type(ability_obj.item) == 'function' then
		local item = ability_obj.item()
		ability_obj.item = item
	end
	if not ability_obj.item then
		minetest.log("warning", ("[robot] ability %s will not be usable until an item is set for it"):format(ability_obj.ability))
	end
	local existing_ability_obj = api.abilities_ability_index[ability_obj.ability]
	if existing_ability_obj then
		minetest.log("warning", ("[robot] overriding %s ability"):format(ability_obj.ability))
		local new_abilities = {}
		for _,ability in ipairs(api.abilities) do
			if ability.ability == ability_obj.ability then
				table.insert(new_abilities, ability_obj)
			else
				table.insert(new_abilities, ability)
			end
		end
		api.abilities = new_abilities
	else
		table.insert(api.abilities, ability_obj)
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

function api.ability_enabled(ability)
	local ability_obj = api.abilities_ability_index[ability]
	if not ability_obj then return false end
	if ability_obj.disabled then return false end
	if not ability_obj.item then return false end
	return ability_obj
end

function api.any_has_ability(nodeinfo, ability, ignore_god_item)
	local ns = nodeinfo.robot_set()
	for _,n in ipairs(ns) do
		if api.has_ability(n, ability, ignore_god_item) then return n end
	end
end

function api.has_ability(nodeinfo, ability, ignore_god_item)
	local ability_obj = api.ability_enabled(ability)
	if not ability_obj then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.parts[info.part].default_abilities or {}) do
		if def_ability == ability then
			return true
		end
	end
	if ability_obj.done_by and not ability_obj.done_by[info.part] then return end

	local extras_enabled_list = string.split(nodeinfo.meta():get_string('extras'),',')
	for _,def in ipairs(extras_enabled_list) do
		if def == ability and api.tiers[info.tier].extra_abilities then
			for _,ab in ipairs(api.tiers[info.tier].extra_abilities) do
				if ab == ability then return true end
			end
		end
	end

	local inv = nodeinfo.inv()
	if not ignore_god_item and not ability_obj.interface_enabled and inv:contains_item('abilities', api.config.god_item) then
		return true
	end
	if inv:contains_item('abilities', ability_obj.item) then
		return true
	end
end

function api.can_have_ability_item(nodeinfo, item)
	if item == api.config.god_item then return true end
	local ability = api.abilities_item_index[item]
	if not ability then return end
	if ability.interface_enabled then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.parts[info.part].default_abilities or {}) do
		if def_ability == ability.ability then return end
	end
	if ability.done_by and not ability.done_by[info.part] then return end

	local inv = nodeinfo.inv()
	if inv:contains_item('abilities', item) then return end

	return true
end

function api.can_have_ability(nodeinfo, ability_name)
	local ability = api.abilities_ability_index[ability_name]
	if not ability then return end
	if ability.interface_enabled then return end
	local info = nodeinfo.info()
	if not info.part then return end
	for _,def_ability in ipairs(api.parts[info.part].default_abilities or {}) do
		if def_ability == ability.ability then return end
	end
	if ability.done_by and not ability.done_by[info.part] then return end

	local inv = nodeinfo.inv()
	if inv:contains_item('abilities', ability.item) then return end

	return true
end

function api.apply_ability(nodeinfo, player_name, ability)
	if ability.modifier then
		if not ability.un_modifier then
			minetest.log("error", "[robot] Ability modifier will not run unless it has an un-modfier method.")
			return
		end
		ability.modifier(nodeinfo, player_name)
	end
end

function api.unapply_ability(nodeinfo, player_name, ability)
	if ability.un_modifier then
		ability.un_modifier(nodeinfo, player_name)
	end
end


local directionParam = {
	values = {
		front = function (nodeinfo)
			return {
				direction = nodeinfo.direction(),
				frontpos = nodeinfo.front(),
			}
		end,
		up = function (nodeinfo)
			local ns = nodeinfo.robot_set()
			return {
				direction = {x=0,y=1,z=0},
				frontpos = vector.add(ns[1].pos(), {x=0,y=1,z=0})
			}
		end,
		down = function (nodeinfo)
			local ns = nodeinfo.robot_set()
			return {
				direction = {x=0,y=-1,z=0},
				frontpos = vector.add(ns[#ns].pos(), {x=0,y=-1,z=0})
			}
		end,
		['up-front'] = function (nodeinfo)
			local ns = nodeinfo.robot_set()
			local direction = vector.add({x=0,y=1,z=0}, nodeinfo.direction())
			return {
				direction = direction,
				frontpos = vector.add(ns[1].pos(), direction),
			}
		end,
		['down-front'] = function (nodeinfo)
			local ns = nodeinfo.robot_set()
			local direction = vector.add({x=0,y=-1,z=0}, nodeinfo.direction())
			return {
				direction = direction,
				frontpos = vector.add(ns[#ns].pos(), direction)
			}
		end,
	},
	parse = function (nodeinfo, dir, def)
		if not dir then dir = def or 'front' end

		if type(dir) ~= 'string' then
			error('looking dir must be a string', 2)
			return
		end
		if not directionParam.values[dir] then
			error(("direction '%s' is invalid"):format(dir), 2)
			return
		end

		return directionParam.values[dir](nodeinfo)
	end
}


-- [[ Turn ]]
robot.add_ability({
	ability = 'turn',
	item = function()
		if minetest.get_modpath('rhotator') then
			return 'rhotator:screwdriver'
		elseif minetest.get_modpath('screwdriver') then
		 return 'screwdriver:screwdriver'
		end
		return "default:acacia_bush_leaves"
	end,
	description = S("Rotate the robot 90 degrees"),
	command_example = "robot.turn(<anticlockwise? true|false/nil>)",
	done_by = { head = true, legs = true },
	act_on = 'all',
	depends_on = 'any',
	action = function (nodeinfo, _part, anticlockwise)
		local ns = nodeinfo.robot_set()
		for _, n in ipairs(ns) do
			local node = n.node()
			n.set_node({
				param2 = anticlockwise
					and (node.param2-1)%4
					or (node.param2+1)%4
			})
		end
	end
})

-- [[ Move ]]
robot.add_ability({
	ability = 'move',
	item = function ()
		if minetest.get_modpath('carts') then
			return "carts:cart"
		end
		return "default:acacia_bush_sapling"
	end,
	description = S("Move one block forwards"),
	done_by = { head = true, legs = true },
	act_on = 'all',
	depends_on = 'any',
	action = function (nodeinfo, _part)
		local ns = nodeinfo.robot_set()

		local meta = nodeinfo.meta()
		local owner = meta:get_string('player_name')
		local above = vector.add(ns[1].pos(), {x=0, y=1, z=0})
		if api.any_has_ability(nodeinfo, 'push') then
			-- ### Step 1: Push nodes in front ###
			local moved = false
			for _,n in ipairs(ns) do
				local new_pos = n.front()
				local success, stack, oldstack = mesecon.mvps_push(new_pos, n.direction(), api.config.max_push, owner)
				if not success then
					if moved then
						minetest.check_for_falling(n.pos())
						minetest.check_for_falling(above)
					end
					if stack == "protected" then
						error("protected area in the way", 2)
						return
					end
					error("blocked", 2)
					return
				end
				mesecon.mvps_move_objects(new_pos, n.direction(), oldstack)
				api.move_robot(n, new_pos)
				moved = true
			end
			-- ### Step 4: Let things fall ###
			if moved then
				minetest.check_for_falling(ns[#ns].pos())
				minetest.check_for_falling(above)
			end
		else
			local can_move = true
			for _,n in ipairs(ns) do
				local frontpos = n.front()
				if minetest.is_protected(frontpos, owner) then
					error("protected area in the way", 2)
					return
				end
				if not api.can_move_to(frontpos) then
					can_move = false
					break
				end
			end
			if not can_move then
				error("blocked", 2)
				return
			end
			-- ### Step 2: Move the movestone ###
			for _,n in ipairs(ns) do
				local new_pos = n.front()
				api.move_robot(n, new_pos)
			end
			-- ### Step 4: Let things fall ###
			minetest.check_for_falling(ns[#ns].pos())
			minetest.check_for_falling(above)
		end
	end
})

-- [[ Climb ]]
robot.add_ability({
	ability = 'climb',
	item = function ()
		if minetest.get_modpath('mesecons_pistons') then
			return 'mesecons_pistons:piston_normal_off'
		end
		return "default:acacia_bush_stem"
	end,
	description = S("Climb up and forwards one block"),
	done_by = { head = true, legs = true },
	act_on = 'all',
	depends_on = 'any',
	action = function (nodeinfo, _part)
		local ns = nodeinfo.robot_set()
		local lastinfo = ns[#ns]
		local meta = nodeinfo.meta()
		local owner = meta:get_string('player_name')

		for _, n in ipairs(ns) do
			local uppos = vector.add(n.front(), {x=0,y=1,z=0})
			if minetest.is_protected(uppos, owner) then
				error("protected area in the way", 2)
				return
			elseif not api.can_move_to(uppos) then
				error("blocked", 2)
				return
			end
		end

		local under_node = minetest.get_node(lastinfo.front())
		local under_node_def  = minetest.registered_nodes[under_node.name]
		if not under_node_def.walkable then
			error("no support", 2)
			return
		end

		-- TODO: ray trace to make sure the hitbox isn't blocking?
		for _, n in ipairs(ns) do
			n.set_pos(vector.add(n.front(), {x=0,y=1,z=0}))
		end
	end
})

-- [[ Look ]]
robot.add_ability({
	ability = "look",
	item = function ()
		if minetest.get_modpath('mesecons_detector') then
			return 'mesecons_detector:node_detector_off'
		elseif minetest.get_modpath('binoculars') then
			return "binoculars:binoculars"
		end
		return "default:acacia_leaves"
	end,
	description = S("Get the name of the node in front of the robot"),
	command_example = "node_name = robot.look(<dir 'up'|'front'/nil|'down'|'up-front'|'down-front'>)",
	done_by = { head = true },
	act_on = 'first',
	depends_on = 'self',
	action = function (nodeinfo, part, dir)
		local hasability = api.any_has_ability(nodeinfo, 'look')
		if not hasability then return end

		local actorinfo = hasability
		if part then
			actorinfo = nodeinfo.parts()[part] or hasability
		end

		local dirPos = directionParam.parse(actorinfo, dir, 'front')

		return minetest.get_node(dirPos.frontpos).name
	end,
	runtime = true
})

-- [[ Locate ]]
robot.add_ability({
	ability = "locate",
	item = function ()
		if minetest.get_modpath('orienteering') then
			return 'orienteering:gps'
		elseif minetest.get_modpath('map') then
			return 'map:mapping_kit'
		end
		return "default:acacia_sapling"
	end,
	act_on = 'last',
	depends_on = 'any',
	description = S("Get the position of the robot"),
	command_example = "node_pos = robot.locate()",
	done_by = { head = true },
	action = function (nodeinfo, part)
		local hasability = api.any_has_ability(nodeinfo, 'locate')
		if not hasability then return end

		local actorinfo = hasability
		if part then
			actorinfo = nodeinfo.parts()[part] or hasability
		end

		local pos = actorinfo.pos()
		return {
			x = pos.x,
			y = pos.y,
			z = pos.z,
		}
	end,
	runtime = true
})

-- [[ Place ]]
robot.add_ability({
	ability = 'place',
	disabled = not minetest.get_modpath('dispenser'),
	item = 'dispenser:dispenser',
	act_on = 'first',
	depends_on = 'self',
	description = S("Place a block down"),
	command_example = "robot.place(<dir 'up'|'front'/nil|'down'|'up-front'|'down-front'>)",
	done_by = { head = true, body = true },
	action = function (nodeinfo, part, dir)
		local hasability = api.any_has_ability(nodeinfo, 'place')
		if not hasability then return end

		local actorinfo = hasability
		if part then
			actorinfo = nodeinfo.parts()[part] or hasability
		end

		local dirPos = directionParam.parse(actorinfo, dir, 'front')
		local direction = dirPos.direction
		local frontpos = dirPos.frontpos
		if dir === 'down' then
			if not api.any_has_ability(nodeinfo, 'climb') then
				error('requires climb ability to place block below', 2)
				return
			end
			frontpos = vector.add(dirPos.frontpos, {x=0,y=1,z=0})
		end

		local meta = actorinfo.meta()
		local owner = meta:get_string('player_name')

		if minetest.is_protected(frontpos, owner) then
			error("protected area in the way", 2)
			return
		end

		local ns = nodeinfo.robot_set()

		local inv_info
		local next_index
		local next_stack
		for _,n in ipairs(ns) do
			local list = n.inv():get_list('main')
			for index, stack in ipairs(list) do
				if not stack:is_empty() then
					next_index = index
					inv_info = n
					next_stack = stack
					break
				end
			end
			if inv_info then break end
		end
		if not inv_info then
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
			index = next_index
		}

		local fuel_used
		if dir == 'down' then
			for i, n in ipairs(ns) do
				local uppos = vector.add(n.pos(), {x=0,y=1,z=0})
				if minetest.is_protected(uppos, owner) then
					error("protected area in the way", 2)
					return
				elseif i == 1 and not api.can_move_to(uppos) then
					error("blocked", 2)
					return
				end
			end
			for _, n in ipairs(ns) do
				local uppos = vector.add(n.pos(), {x=0,y=1,z=0})
				api.move_robot(n, uppos)
			end

			fuel_used = 2
		end

		player_opts.pos = actorinfo.pos()
		player_opts.meta = inv_info.meta()

		next_stack = inv_info.inv():get_stack('main', next_index)
		local player = dispenser.actions.fake_player(next_stack, player_opts)
		if not player then
			error("player not logged in", 2)
			return
		end

		local result = def.on_place(next_stack, player, {
			type="node",
			under=frontpos,
			above=frontpos
		})
		minetest.check_for_falling(frontpos)
		if result then
			inv_info.inv():set_stack('main', next_index, result)
		end
		return nil, fuel_used
	end
})

-- [[ Use ]]
robot.add_ability({
	ability = 'use',
	disabled = not minetest.get_modpath('dispenser'),
	item = function ()
		if minetest.get_modpath('bones') then
			return "bones:bones"
		end
		return "default:acacia_tree"
	end,
	act_on = 'first',
	depends_on = 'self',
	description = S("Use an item (not a tool)"),
	command_example = "robot.use(<dir 'up'|'front'/nil|'down'|'up-front'|'down-front'>)",
	done_by = { head = true, body = true },
	action = function (nodeinfo, part, dir)
		local hasability = api.any_has_ability(nodeinfo, 'use')
		if not hasability then return end

		local actorinfo = hasability
		if part then
			actorinfo = nodeinfo.parts()[part] or hasability
		end

		local dirPos = directionParam.parse(actorinfo, dir, 'front')

		local inv_info
		local next_stack
		local next_index
		for _,n in ipairs(nodeinfo.robot_set()) do
			local node_inv = n.inv()
			local list = node_inv:get_list('main')
			for index,stack in ipairs(list) do
				if not stack:is_empty() then
					next_stack = stack
					next_index = index
					inv_info = n
					break
				end
			end
			if inv_info then break end
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
			front = dirPos.frontpos,
			dir = dirPos.direction,
			pos = actorinfo.pos(),
			meta = inv_info.meta(),
			index = next_index
		})
		if not player then
			error("player not logged in", 2)
			return
		end
		local result = def.on_use(next_stack, player, {
			type="node",
			under=dirPos.frontpos,
			above=vector.add(dirPos.frontpos, {x=0,y=1,z=0})
		})
		if result then
			inv_info.inv():set_stack('main', next_index, result)
		end
	end
})

-- [[ Switch ]]
robot.add_ability({
	ability = 'switch',
	disabled = not minetest.get_modpath('tubelib'),
	item = function ()
		if minetest.get_modpath('tubelib') then
			return 'tubelib:button'
		end
		return "default:acacia_wood"
	end,
	act_on = 'first',
	depends_on = 'self',
	description = S("Switch a tubelib machine on and off"),
	command_example = "robot.switch(<dir 'up'|'front'/nil|'down'|'up-front'|'down-front'>)",
	done_by = { head = true, body = true },
	action = function (nodeinfo, part, dir)
		local hasability = api.any_has_ability(nodeinfo, 'switch')
		if not hasability then return end

		local actorinfo = hasability
		if part then
			actorinfo = nodeinfo.parts()[part] or hasability
		end

		local dirPos = directionParam.parse(actorinfo, dir, 'front')

		local tube_meta = minetest.get_meta(dirPos.frontpos)

		local state = tube_meta:get_int("tubelib_state")
		if not state then return end

		local number = tubelib.get_node_number(dirPos.frontpos)
		if not number or number == "" then return end

		local meta = actorinfo.meta()
		local owner = meta:get_string('player_name')

		tubelib.send_message(number, owner, nil, state == tubelib.STOPPED and "on" or "off", nil)
	end
})

-- [[ Push ]]
robot.add_ability({
	ability = 'push',
	disabled = not minetest.get_modpath('mesecons_mvps'),
	item = function ()
		if minetest.get_modpath('mesecons_movestones') then
			return "mesecons_movestones:movestone"
		end
		return "default:apple"
	end,
	act_on = 'all',
	depends_on = 'any',
	done_by = { legs = true, body = true },
	description = S("Push a block when moving forwards")
})

-- [[ Carry ]]
robot.add_ability({
	ability = 'carry',
	item = function ()
		if minetest.get_modpath('unified_inventory') then
			return 'unified_inventory:bag_large'
		elseif minetest.get_modpath('default') then
			return 'default:chest'
		end
		return "default:aspen_leaves"
	end,
	act_on = 'self',
	depends_on = 'self',
	description = S("Expand the item inventory"),
	done_by = { legs = true, body = true },
	updates_formspec = true,
	modifier = function(nodeinfo, player_name)
		local info = nodeinfo.info()
		local inv = nodeinfo.inv()

		local new_size = api.tiers[info.tier].form_size*2
		if api.has_ability(nodeinfo, 'fuel_swap') then
			new_size = new_size - 4
			inv:set_size('fuel', inv:get_size('fuel') + 3)
		end
		inv:set_size('main', new_size)
	end,
	un_modifier = function(nodeinfo, player_name)
		local info = nodeinfo.info()
		local inv = nodeinfo.inv()

		local new_size = api.tiers[info.tier].inventory_size
		if api.has_ability(nodeinfo, 'fuel_swap') then
			new_size = new_size - 1
			local new_fuel_size = inv:get_size('fuel') - 3

			local fuel_list = inv:get_list('fuel')
			for i,stack in ipairs(fuel_list) do
				if i > new_fuel_size then
					minetest.add_item(vector.add(nodeinfo.pos(), {x=0,y=0.5,z=0}), stack)
				end
			end
			inv:set_size('fuel', new_fuel_size)
		end
		-- Spit out any extra items
		local list = inv:get_list('main')
		for i,stack in ipairs(list) do
			if i > new_size then
				minetest.add_item(vector.add(nodeinfo.pos(), {x=0,y=0.5,z=0}), stack)
			end
		end

		inv:set_size('main', new_size)
	end,
})

-- [[ Fuel ]]
robot.add_ability({
	ability = 'fuel',
	item = function ()
		if minetest.get_modpath('unified_inventory') then
			return 'unified_inventory:bag_small'
		elseif minetest.get_modpath('default') then
			return 'default:furnace'
		end
		return "default:aspen_sapling"
	end,
	act_on = 'self',
	depends_on = 'self',
	description = S("Expand the fuel inventory"),
	done_by = { head = true, legs = true, body = true },
	updates_formspec = true,
	modifier = function(nodeinfo, player_name)
		local inv = nodeinfo.inv()
		inv:set_size('fuel', inv:get_size('fuel')+3)
	end,
	un_modifier = function(nodeinfo, player_name)
		local inv = nodeinfo.inv()

		-- Spit out any extra items
		local list = inv:get_list('fuel')
		local new_size = inv:get_size('fuel')-3
		for i,stack in ipairs(list) do
			if i > new_size then
				minetest.add_item(vector.add(nodeinfo.pos(), {x=0,y=0.5,z=0}), stack)
			end
		end

		inv:set_size('fuel', new_size)
	end,
})

-- [[ Fill ]]
robot.add_ability({
	ability = 'fill',
	disabled = not minetest.get_modpath('tubelib'),
	item = function ()
		if minetest.get_modpath('tubelib') then
			return 'tubelib:tubeS'
		end
		return "default:aspen_tree"
	end,
	act_on = 'self',
	depends_on = 'self',
	done_by = { legs = true, body = true },
	description = S("Fill and empty the inventory using pushers"),
})

-- [[ Speed ]]
robot.add_ability({
	ability = 'speed',
	item = function ()
		if minetest.get_modpath('terumet') then
			return 'terumet:item_upg_speed_up'
		elseif minetest.get_modpath('carts') then
			return 'carts:powerrail'
		end
		return "default:aspen_wood"
	end,
	act_on = 'all',
	depends_on = 'any',
	description = S("Make the robot run twice as fast"),
	done_by = { legs = true },
	modifier = function (nodeinfo)
		if not nodeinfo.speed_enabled() then
			nodeinfo.meta():set_int('robot_speed', 1)
		end
	end,
	un_modifier = function (nodeinfo)
		if nodeinfo.speed_enabled() then
			nodeinfo.meta():set_int('robot_speed', 0)
		end
	end
})

-- [[ Connectivity ]]
robot.add_ability({
	ability = 'connectivity',
	item = function ()
		if minetest.get_modpath('digistuff') then
			return "digistuff:insulated_straight"
		end
		return "default:obsidian_glass"
	end,
	act_on = 'self',
	depends_on = 'self',
	description = S("Connect to robot parts above"),
	done_by = { legs = true, body = true },
	updates_formspec = true,
	modifier = function (nodeinfo)
		api.correct_connection(nodeinfo)
	end,
	un_modifier = function (nodeinfo)
		api.correct_connection(nodeinfo)
	end,
})

-- [[ Fuel Swap ]]
robot.add_ability({
	interface_enabled = true,
	ability = "fuel_swap",
	item = function ()
		if minetest.get_modpath('replacer') then
			return "replacer:replacer"
		end
		return "default:blueberries"
	end,
	act_on = 'self',
	depends_on = 'self',
	description = S("Swap some normal inventory for fuel inventory"),
	done_by = { legs = true, body = true, head = true },
	updates_formspec = true,
	modifier = function(nodeinfo, player_name)
		local inv = nodeinfo.inv()
		local size_change = 1
		if api.has_ability(nodeinfo, 'carry') then
			size_change = size_change + 3
		end

		inv:set_size('fuel', inv:get_size('fuel')+size_change)

		-- Spit out any extra items
		local list = inv:get_list('main')
		local new_size = inv:get_size('main')-size_change
		for i,stack in ipairs(list) do
			if i > new_size then
				minetest.add_item(vector.add(nodeinfo.pos(), {x=0,y=0.5,z=0}), stack)
			end
		end
		inv:set_size('main', new_size)
	end,
	un_modifier = function(nodeinfo, player_name)
		local inv = nodeinfo.inv()
		local size_change = 1
		if api.has_ability(nodeinfo, 'carry') then
			size_change = size_change + 3
		end

		inv:set_size('main', inv:get_size('main')+size_change)

		-- Spit out any extra items
		local list = inv:get_list('fuel')
		local new_size = inv:get_size('fuel')-size_change
		for i,stack in ipairs(list) do
			if i > new_size then
				minetest.add_item(vector.add(nodeinfo.pos(), {x=0,y=0.5,z=0}), stack)
			end
		end
		inv:set_size('fuel', new_size)
	end,
})

-- [[ Boost ]]
robot.add_ability({
	interface_enabled = true,
	ability = "boost",
	item = function ()
		if minetest.get_modpath('orienteering') then
			return "orienteering:speedometer"
		end
		return "default:blueberry_bush_leaves"
	end,
	act_on = 'all',
	depends_on = 'any',
	description = S("Speed up but use more fuel randomly"),
	done_by = { legs = true, body = true, head = true },
	modifier = function (nodeinfo)
		if not nodeinfo.boost_enabled() then
			nodeinfo.meta():set_int('robot_boost', 1)
		end
	end,
	un_modifier = function (nodeinfo)
		if nodeinfo.boost_enabled() then
			nodeinfo.meta():set_int('robot_boost', 0)
		end
	end
})


function api.stop_action (nodeinfo)
	api.set_status(nodeinfo, 'stopped')
	return nil, 0
end
function api.log_action (nodeinfo,_part,...)
	local meta = nodeinfo.meta()
	local owner = meta:get_string('player_name')
	minetest.chat_send_player(owner, "[robot] LOG: "..dump({...}))
	return nil, 0
end
