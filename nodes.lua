local api = robot.internal_api
local S = api.translator



local function on_timer (pos, dtime)
	local meta = minetest.get_meta(pos)

	if meta:get_string('status') ~= 'running' then
		return false
	end

	local old_pos_str = meta:get_string('pos')
	if old_pos_str ~= "" then
		local old_pos = minetest.string_to_pos(old_pos_str)
		local diff = vector.subtract(old_pos, pos)
		if diff.y > api.config.max_fall then
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
		inv:remove_item('fuel', api.config.fuel_item)
		return false
	end

	local ok, errmsg, new_pos, fuel_used = api.execute(pos, meta)
	if new_pos then
		meta = minetest.get_meta(new_pos)
		inv = meta:get_inventory()
	end
	if fuel_used and fuel_used > 0 then
		inv:remove_item('fuel', ItemStack({
			name=api.config.fuel_item,
			count=fuel_used
		}))
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




local stopped_props = table.copy(api.basic_node)
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


local running_props = table.copy(api.basic_node)
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


local error_props = table.copy(api.basic_node)
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


local broken_props = table.copy(api.basic_node)
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
if api.config.repair_item ~= 'tubelib:repairkit' then
	broken_props.on_punch = function (pos, node, puncher, pointed_thing)
		if not (puncher and puncher:is_player()) then return end

		if node.name ~= "robot:robot_broken" then return end

		local item = puncher:get_wielded_item()
		if item:is_empty() then return end
		if item:get_name() ~= api.config.repair_item then return end

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
