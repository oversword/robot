local api = robot.internal_api

local S = api.translator

api.abilities = {}
api.abilities_item_index = {}
api.abilities_ability_index = {}

minetest.register_craftitem(api.config.god_item, {
	description = "God Ability",
	inventory_image = 'robot_god_ability_item.png'
})

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

function api.has_ability(meta, inv, ability)
	if not api.abilities_ability_index[ability] then
		return false
	end
	if not inv then
		inv = meta:get_inventory()
	end
	if not inv:contains_item('abilities', api.abilities_ability_index[ability].item) then
		if inv:contains_item('abilities', api.config.god_item) then
			return true
		end
		return false
	end
	return true
end

function api.apply_ability(pos, player_name, ability)
	if ability.modifier then
		if not ability.un_modifier then
			minetest.log("error", "[robot] Ability modifier will not run unless it has an un-modfier method.")
			return
		end
		ability.modifier(pos, player_name)
	end
end

function api.unapply_ability(pos, player_name, ability)
	if ability.un_modifier then
		ability.un_modifier(pos, player_name)
	end
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
		done_by = { head = true, legs = true },
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
		done_by = { head = true, legs = true },
		action = function (pos)
			local node = minetest.get_node(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local meta = minetest.get_meta(pos)

			local owner = meta:get_string('player_name')
			if api.has_ability(meta, nil, 'push') then
				-- ### Step 1: Push nodes in front ###
				local success, stack, oldstack = mesecon.mvps_push(frontpos, direction, api.config.max_push, owner)
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
		done_by = { head = true, legs = true },
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
		done_by = { head = true },
		action = function (pos)
			local node = minetest.get_node(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local front_node = minetest.get_node(frontpos)

			return front_node.name
		end,
		runtime = true
	})
end


local locate_ability_item
if minetest.get_modpath('orienteering') then
	locate_ability_item = 'orienteering:gps'
elseif minetest.get_modpath('map') then
	locate_ability_item = 'map:mapping_kit'
end
if locate_ability_item then
	robot.add_ability({
		ability = "locate",
		item = locate_ability_item,
		description = S("Get the position of the robot"),
		command_example = "node_pos = robot.locate()",
		done_by = { head = true },
		action = function (pos)
			return {
				x = pos.x,
				y = pos.y,
				z = pos.z,
			}
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
		done_by = { head = true, body = true },
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
				if not api.has_ability(meta, inv, 'climb') then
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

			local result = def.on_place(next_stack, player, {
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
		done_by = { head = true, body = true },
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


local switch_ability_item
if minetest.get_modpath('tubelib') then
	switch_ability_item = 'tubelib:button'
end
if switch_ability_item and minetest.get_modpath('tubelib') then
	robot.add_ability({
		ability = 'switch',
		item = switch_ability_item,
		description = S("Switch a tubelib machine on and off"),
		done_by = { head = true, body = true },
		action = function (pos)
			local node = minetest.get_node(pos)

			local direction = vector.subtract({x=0,y=0,z=0}, minetest.facedir_to_dir(node.param2))
			local frontpos = vector.add(pos, direction)

			local tube_meta = minetest.get_meta(frontpos)

			local state = tube_meta:get_int("tubelib_state")
			local number = tubelib.get_node_number(frontpos)

			if not state or not number or number == "" then return end

			local meta = minetest.get_meta(pos)
			local owner = meta:get_string('player_name')

			tubelib.send_message(number, owner, nil, state == tubelib.STOPPED and "on" or "off", nil)
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
		done_by = { legs = true, body = true },
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
		done_by = { legs = true, body = true },
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
		done_by = { head = true, legs = true, body = true },
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
		done_by = { legs = true, body = true },
		description = S("Fill and empty the inventory using pushers"),
	})
end



local speed_ability_item
if minetest.get_modpath('terumet') then
	speed_ability_item = 'terumet:item_upg_speed_up'
elseif minetest.get_modpath('carts') then
	speed_ability_item = 'carts:powerrail'
end
if speed_ability_item then
	robot.add_ability({
		ability = 'speed',
		item = speed_ability_item,
		description = S("Make the robot run twice as fast"),
		done_by = { legs = true, head = true },
		modifier = function (pos)
			local node = minetest.get_node(pos)
			node.param1 = 1
			minetest.swap_node(pos, node)
		end,
		un_modifier = function (pos)
			local node = minetest.get_node(pos)
			node.param1 = 0
			minetest.swap_node(pos, node)
		end
	})
end

--[[
programibility
digilines programability?
connectivity

tiers = {
	man = {
		delay = 2,
		ability_slots = 5,
		inventory_size = 1,
		form_size = 8,
	},
	devil = {
		delay = 3,
		ability_slots = 6,
		inventory_size = 2,
		form_size = 9,
		extra_abilities = {
			{
				name = "boost",
				description = "Speed up but use more fuel randomly",
			},
		}
	},
	god = {
		delay = 4,
		ability_slots = 7,
		inventory_size = 4,
		form_size = 10,
		extra_abilities = {
			{
				name = "fuel_swap",
				description = "Swap some normal inventory for fuel inventory",
			},
			{
				name = "boost",
				description = "Speed up but use more fuel randomly",
			},
		}
	},
}

head = {
},
body = {
	connects_above = {head=true},
	default_abilities = {carry=true,fuel=true}
},
legs = {
	connects_above = {head=true,body=true},
	default_abilities = {move=true,turn=true}
}

]]


function api.stop_action (pos)
	api.set_status(pos, minetest.get_meta(pos), 'stopped')
	return nil, 0
end
function api.log_action (pos,...)
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string('player_name')
	minetest.chat_send_player(owner, "[robot] LOG: "..dump({...}))
	return nil, 0
end
