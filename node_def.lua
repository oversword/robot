local api = robot.internal_api
local S = api.translator

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == 'fuel' then
		-- Main stack only accepts fuel
		if stack:get_name() == api.config.fuel_item then
			return stack:get_count()
		end
	elseif listname == 'abilities' then
		-- Ability stack only accepts one of each ability item
		local item = stack:get_name()
		if api.abilities_item_index[item] or item == api.config.god_item then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if not inv:contains_item(listname, item) then
				return 1
			end
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

	local player_name = player:get_player_name()
	local item_name = stack:get_name()
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if item_name == api.config.god_item then
		for _,ability in ipairs(api.abilities) do
			if not inv:contains_item(listname, ability.item) then
				api.apply_ability(pos, player_name, ability)
			end
		end
	elseif not inv:contains_item(listname, api.config.god_item) then
		local ability = api.abilities_item_index[item_name]
		api.apply_ability(pos, player_name, ability)
	end
end
local function on_metadata_inventory_take(pos, listname, index, stack, player)
	if listname ~= 'abilities' then return end

	local player_name = player:get_player_name()
	local item_name = stack:get_name()
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if item_name == api.config.god_item then
		for _,ability in ipairs(api.abilities) do
			if not inv:contains_item(listname, ability.item) then
				api.unapply_ability(pos, player_name, ability)
			end
		end
	elseif not inv:contains_item(listname, api.config.god_item) then
		local ability = api.abilities_item_index[item_name]
		api.unapply_ability(pos, player_name, ability)
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

function api.after_place_node(pos, player, itemstack)
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
		local player_name = player:get_name()
		local ability_table = minetest.deserialize(ability_str)
		local inv = meta:get_inventory()
		for i,item in ipairs(ability_table) do
			if item ~= "" then
				inv:set_stack('abilities', i, item)

				if item == api.config.god_item then
					for _,ability in ipairs(api.abilities) do
						-- if not exists already
						api.apply_ability(pos, player_name, ability)
					end
				else
					local ability = api.abilities_item_index[item]
					api.apply_ability(pos, player_name, ability)
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
	api.start_timer(pos, minetest.get_node(pos).param1 == 1)
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	local meta = minetest.get_meta(pos)
	if meta:get_string('status') == 'running' then
		api.set_status(pos, meta, 'stopped')
	end
end


api.basic_node = {
	description = S("Automated Robot"),
	groups = {falling_node = 1, cracky=2},

	buildable_to = false,
	paramtype = "none",
	paramtype2 = "facedir",
	is_ground_content = false,
	stack_max = 1,
	drop = '',

	on_construct = on_construct,
	after_place_node = api.after_place_node,
	on_receive_fields = api.on_receive_fields,

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
	api.basic_node.on_rotate = screwdriver.disallow
end


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
			if item:get_name() == api.config.fuel_item then
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
	if api.config.repair_item == 'tubelib:repairkit' then
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
