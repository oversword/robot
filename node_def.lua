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
		if api.can_have_ability_item(api.nodeinfo(pos), item) then
			return 1
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
	local nodeinfo = api.nodeinfo(pos)
	local update_formspec = false
	if item_name == api.config.god_item then
		for _,ability in ipairs(api.abilities) do
			if not ability.interface_enabled
			and api.can_have_ability(nodeinfo, ability.ability)
			and not api.has_ability(nodeinfo, ability.ability, true)
			then
				api.apply_ability(nodeinfo, player_name, ability)
				if ability.updates_formspec then
					update_formspec = true
				end
			end
		end
	elseif not nodeinfo.inv():contains_item(listname, api.config.god_item) then
		local ability = api.abilities_item_index[item_name]
		api.apply_ability(nodeinfo, player_name, ability)
		if ability.updates_formspec then
			update_formspec = true
		end
	end
	if update_formspec then
		api.update_formspec(nodeinfo)
		if api.formspec_data[player_name]
			and api.formspec_data[player_name].psuedo_metadata
		then
			minetest.show_formspec(player_name, 'robot_inventory', nodeinfo.meta():get_string('formspec'))
		end
	end
end

local function on_metadata_inventory_take(pos, listname, index, stack, player)
	if listname ~= 'abilities' then return end

	local player_name = player:get_player_name()
	local item_name = stack:get_name()
	local nodeinfo = api.nodeinfo(pos)
	local update_formspec = false
	if item_name == api.config.god_item then
		for _,ability in ipairs(api.abilities) do
			if not ability.interface_enabled
			and api.can_have_ability(nodeinfo, ability.ability)
			and not api.has_ability(nodeinfo, ability.ability)
			then
				api.unapply_ability(nodeinfo, player_name, ability)
				if ability.updates_formspec then
					update_formspec = true
				end
			end
		end
	elseif not nodeinfo.inv():contains_item(listname, api.config.god_item) then
		local ability = api.abilities_item_index[item_name]
		-- if not api.has_ability(nodeinfo, ability.ability) then
			api.unapply_ability(nodeinfo, player_name, ability)
			if ability.updates_formspec then
				update_formspec = true
			end
		-- end
	end
	if update_formspec then
		api.update_formspec(nodeinfo)
		if api.formspec_data[player_name]
			and api.formspec_data[player_name].psuedo_metadata
		then
			minetest.show_formspec(player_name, 'robot_inventory', nodeinfo.meta():get_string('formspec'))
		end
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
	local tier, part, status = api.robot_def(oldnode.name)
	local stack = ItemStack({
		name = status == 'broken'
			and api.robot_name(tier, part, 'broken')
			or api.robot_name(tier, part, 'stopped'),
		count = 1
	})
	local stackmeta = stack:get_meta()

	stackmeta:set_int('ignore_errors', oldmeta_table.fields.ignore_errors or 0)
	stackmeta:set_string('code', oldmeta_table.fields.code)
	stackmeta:set_string('memory', oldmeta_table.fields.memory)
	stackmeta:set_string('extras', oldmeta_table.fields.extras)
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
	if not (player and player:is_player()) then return end
	local stackmeta = itemstack:get_meta()
	local code = stackmeta:get_string('code')
	local memory = stackmeta:get_string('memory')
	local ability_str = stackmeta:get_string('abilities')
	local ignore_errors = stackmeta:get_int('ignore_errors')
	local extras = stackmeta:get_string('extras')

	local nodeinfo = api.nodeinfo(pos)
	local info = nodeinfo.info()
	local meta = nodeinfo.meta()

	meta:set_string('code', code)
	meta:set_int('ignore_errors', ignore_errors)
	if memory ~= "" then
		meta:set_string('memory', minetest.deserialize(memory))
	end
	if player and player:is_player() then
		local inv = nodeinfo.inv()
		local player_name = player:get_player_name()
		local ability_table = ability_str ~= "" and minetest.deserialize(ability_str) or {}

		local god_ability_applied = false
		for i,item in ipairs(ability_table) do
			if item == api.config.god_item then
				for _,ability in ipairs(api.abilities) do
					if not ability.interface_enabled
					and api.can_have_ability(nodeinfo, ability.ability)
					then
						api.apply_ability(nodeinfo, player_name, ability)
					end
				end
				god_ability_applied = true
				break
			end
		end

		if not god_ability_applied then
			for _,ability in ipairs(api.parts[info.part].default_abilities or {}) do
				api.apply_ability(nodeinfo, player_name, api.abilities_ability_index[ability])
			end
		end

		meta:set_string('extras', extras)
		if api.tiers[info.tier].extra_abilities then
			local extras_enabled_list = string.split(extras,',')
			for _,ability in ipairs(extras_enabled_list) do
				for _,ab in ipairs(api.tiers[info.tier].extra_abilities) do
					if ab == ability then
						api.apply_ability(nodeinfo, player_name, api.abilities_ability_index[ability])
						break
					end
				end
			end
		end

		for i,item in ipairs(ability_table) do
			if item ~= "" then
				inv:set_stack('abilities', i, item)
				if not god_ability_applied then
					api.apply_ability(nodeinfo, player_name, api.abilities_item_index[item])
				end
			end
		end
		meta:mark_as_private("memory")
		meta:mark_as_private('code')

		meta:set_string('player_name', player:get_player_name())

		api.update_formspec(nodeinfo)
	end

end

function api.correct_connection(nodeinfo)
	if api.is_connective(nodeinfo) then
		if api.is_connected(nodeinfo) then
			if not api.is_above_connective(nodeinfo) then
				api.set_connected(nodeinfo, false)
			end
		else
			if api.is_above_connective(nodeinfo) then
				api.set_connected(nodeinfo, true)
			end
		end
	end
end

local function on_destruct(pos)
	api.correct_connection(api.nodeinfo(vector.subtract(pos, {x=0,y=1,z=0})))
end
local function after_construct(pos)

	local nodeinfo = api.nodeinfo(pos)
	local meta = nodeinfo.meta()

	local old_pos_str = meta:get_string('pos')
	local any_diff = false
	if old_pos_str ~= "" then
		local old_pos = minetest.string_to_pos(old_pos_str)
		local diff = vector.subtract(old_pos, pos)
		if diff.y > api.tiers[nodeinfo.info().tier].max_fall then
			api.set_status(nodeinfo, 'broken')
			meta:set_string('error', S("Ouch: internal damage"))
		end
		any_diff = diff.x ~= 0 or diff.y~= 0 or diff.z ~= 0
	end
	if old_pos_str == "" or any_diff then
		api.correct_connection(nodeinfo)
		api.correct_connection(api.nodeinfo(vector.subtract(pos, {x=0,y=1,z=0})))
	end
	meta:set_string('pos', minetest.pos_to_string(pos))

		api.stop_timer(nodeinfo)
		-- Need to do this so we can keep running after falling
		if nodeinfo.info().status == 'running' then
			api.start_timer(nodeinfo)
		end
end
local function on_construct(pos)
	local nodeinfo = api.nodeinfo(pos)
	local meta = nodeinfo.meta()
	local info = nodeinfo.info()
	local inv = nodeinfo.inv()
	local node = nodeinfo.node()
	local tier_def = api.tiers[info.tier]

	meta:set_string('code', '')
	meta:set_string('player_name', '??')
	-- meta:set_string('pos', minetest.pos_to_string(pos))
	meta:set_int('ignore_errors', 0)
	meta:set_string('memory', minetest.serialize({}))

	meta:mark_as_private("memory")
	meta:mark_as_private('code')

	inv:set_size('fuel', tier_def.fuel_size or 1)
	inv:set_size('main', tier_def.inventory_size or 1)
	local default_abilities = 0
	for _,ability in ipairs(api.parts[info.part].default_abilities or {}) do
		if api.ability_enabled(ability) then
			default_abilities = default_abilities + 1
		end
	end
	inv:set_size('abilities', (tier_def.ability_slots or 5)-default_abilities)

	minetest.after(0.1, after_construct, pos)
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	local nodeinfo = api.nodeinfo(pos, node)
	if nodeinfo.info().status == 'running' then
		api.set_status(nodeinfo, 'stopped')
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

	after_destruct = on_destruct,
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
	api.tubelib_options = {
		on_pull_item = function(pos, side, player_name)
			local nodeinfo = api.nodeinfo(pos)
			if api.has_ability(nodeinfo, 'fill') then
				local meta = nodeinfo.meta()
				return tubelib.get_item(meta, 'main')
			end
		end,
		on_push_item = function(pos, side, item, player_name)
			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if item:get_name() == api.config.fuel_item then
				return tubelib.put_item(meta, 'fuel', item)
			elseif api.has_ability(nodeinfo, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
		on_unpull_item = function(pos, side, item, player_name)
			local nodeinfo = api.nodeinfo(pos)
			local meta = nodeinfo.meta()
			if api.has_ability(nodeinfo, 'fill') then
				return tubelib.put_item(meta, 'main', item)
			end
			return false
		end,
	}
	if api.config.repair_item == 'tubelib:repairkit' then
		api.tubelib_options.on_node_repair = function(pos)
			local nodeinfo = api.nodeinfo(pos)
			if nodeinfo.info().status ~= 'broken' then return end
			api.clear_error(nodeinfo)
			api.set_status(nodeinfo, 'stopped')
			return true
		end
	end
end
