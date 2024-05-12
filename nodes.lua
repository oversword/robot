local api = robot.internal_api
local S = api.translator

local function get_tiles(tile_set, state)
	local ret = {}
	for i,tile in ipairs(tile_set) do
		if type(tile) == 'string' then
			ret[i] = tile
		elseif tile[state] then
			ret[i] = tile[state]
		else
			ret[i] = tile
		end
	end
	return ret
end

local function on_timer (pos, dtime)
	local nodeinfo = api.nodeinfo(pos)

	if nodeinfo.info().status ~= 'running' then
		return false
	end
	local meta = nodeinfo.meta()

	local empty = true
	for _,n in ipairs(nodeinfo.robot_set()) do
		if not n.inv():is_empty('fuel') then
			empty = false
			break
		end
	end
	if empty then
		api.set_error(nodeinfo, S("Out of fuel"))
		return false
	end

	-- If there's no code, stop running but keep the skin
	-- so builders can use the running face without using multiple fuel
	if meta:get_string('code') == "" then
		local count = 1
		for _,n in ipairs(nodeinfo.robot_set()) do
			local removed = n.inv():remove_item('fuel', ItemStack({
				name=api.config.fuel_item,
				count=count
			}))
			count = count - removed:get_count()
			if count <= 0 then
				break
			end
		end

		return false
	end

	local ok, errmsg, newinfo, fuel_used = api.execute(nodeinfo)
	if newinfo then
		nodeinfo = newinfo
	end
	if nodeinfo.any_boost_enabled() and math.random() > 0.5 then
		fuel_used = (fuel_used or 0) + 1
	end
	if fuel_used and fuel_used > 0 then
		local count = fuel_used
		for _,n in ipairs(nodeinfo.robot_set()) do
			local removed = n.inv():remove_item('fuel', ItemStack({
				name=api.config.fuel_item,
				count=count
			}))
			count = count - removed:get_count()
			if count <= 0 then
				break
			end
		end
	end

	if not ok then
		-- minetest.log("error",  errmsg)
		return not api.set_error(nodeinfo, errmsg)
	end

	if errmsg ~= "" then
		nodeinfo.meta():set_string('error', errmsg)
	end

	return true
end

for _,tier in ipairs(api.tiers()) do
	local tier_def = api.tier(tier)
	local tier_props = table.copy(api.basic_node)

	if tier_def.extra_props then
		for prop, val in pairs(tier_def.extra_props) do
			tier_props[prop] = val
		end
	end

	for _,part in ipairs(api.parts()) do
		local part_def = api.part(part)
		local part_props = table.copy(tier_props)

		if tier_def.models and tier_def.models[part] then
			part_props.drawtype = "mesh"
			part_props.mesh = tier_def.models[part]
		elseif tier_def.node_boxes and tier_def.node_boxes[part] then
			part_props.drawtype = "nodebox"
			part_props.node_box = tier_def.node_boxes[part]
		end

		if part_def.description then
			part_props.description = part_props.description .. " ("..part_def.description..")"
		end

		local stopped_name = api.robot_name(tier, part, 'stopped')
		local stopped_props = table.copy(part_props)
		stopped_props.tiles = get_tiles(part_def.tiles[tier], 'stopped')
		api.record_robot_name(stopped_name, tier, part, 'stopped')
		minetest.register_node(stopped_name, stopped_props)

		local running_name = api.robot_name(tier, part, 'running')
		local running_props = table.copy(part_props)
		running_props.tiles = get_tiles(part_def.tiles[tier], 'running')
		running_props.groups.not_in_creative_inventory = 1
		running_props.on_timer = on_timer
		api.record_robot_name(running_name, tier, part, 'running')
		minetest.register_node(running_name, running_props)

		local error_name   = api.robot_name(tier, part, 'error'  )
		local error_props = table.copy(part_props)
		error_props.tiles = get_tiles(part_def.tiles[tier], 'error')
		error_props.groups.not_in_creative_inventory = 1
		api.record_robot_name(error_name  , tier, part, 'error'  )
		minetest.register_node(error_name, error_props)

		local broken_name  = api.robot_name(tier, part, 'broken' )
		local broken_props = table.copy(part_props)
		broken_props.tiles = get_tiles(part_def.tiles[tier], 'broken')
		broken_props.groups.not_in_creative_inventory = 1
		broken_props.description = S("Broken Automated Robot")
		if api.config.repair_item ~= 'tubelib:repairkit' then
			broken_props.on_punch = function (pos, node, puncher, pointed_thing)
				if not (puncher and puncher:is_player()) then return end

				local nodeinfo = api.nodeinfo(pos, node)
				local info = nodeinfo.info()
				if info.status ~= 'broken' then return end

				local item = puncher:get_wielded_item()
				if item:is_empty() then return end
				if item:get_name() ~= api.config.repair_item then return end

				local taken = item:take_item(1)
				if taken:is_empty() then return end

				api.clear_error(nodeinfo)
				api.set_status(nodeinfo, 'stopped')

				return puncher:set_wielded_item(item)
			end
		end
		api.record_robot_name(broken_name , tier, part, 'broken' )
		minetest.register_node(broken_name, broken_props)

		if api.tubelib_options then
			tubelib.register_node(
				stopped_name,
				{
					stopped_name,
					error_name,
					broken_name,
					running_name
				},
				api.tubelib_options
			)
		end

	end

end
