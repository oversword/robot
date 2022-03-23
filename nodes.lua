local api = robot.internal_api
local S = api.translator



local function on_timer (pos, dtime)
	local nodeinfo = api.nodeinfo(pos)

	if nodeinfo.info().status ~= 'running' then
		return false
	end
	local meta = nodeinfo.meta()

	local inv = nodeinfo.inv()

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
	-- so builders can use the running face
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
		fuel_used = fuel_used + 1
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
		api.set_error(nodeinfo, errmsg)
		return false
	end

	if errmsg ~= "" then
		nodeinfo.meta():set_string('error', errmsg)
	end

	return true
end

local tiles = {
	top = 'robot_top.png',
	bottom = 'robot_bottom.png',
	side = {
		stopped = 'robot_side.png',
		running = {
			name = 'robot_side_running.png',
			animation = {
			type = "vertical_frames",
				aspect_w = 8,
				aspect_h = 8,
				length = 1,
			}
		},
		error = {
			name = 'robot_side_error.png',
			animation = {
			type = "vertical_frames",
				aspect_w = 8,
				aspect_h = 8,
				length = 1,
			}
		},
		broken = 'robot_side_broken.png'
	},
	back = {
		stopped = 'robot_back.png',
		running = 'robot_back_running.png',
		error = 'robot_back_error.png',
		broken = 'robot_back_error.png',
	},
	front = {
		stopped = 'robot_front.png',
		running = 'robot_front_running.png',
		error = 'robot_front_error.png',
		broken = 'robot_front_broken.png',
	}
}

api.parts = {
	head = {
		name_postfix = "",
		tiles = {
			-- up, down, right, left, back, front
			tiles.top,
			tiles.bottom,
			tiles.side,
			tiles.side,
			tiles.back,
			tiles.front,
		}
	},
	body = {
		name_postfix = "_body",
		tiles = {
			-- up, down, right, left, back, front
			tiles.top,
			tiles.bottom,
			tiles.side,
			tiles.side,
			tiles.back,
			tiles.top,
		},
		connects_above = {head=true},
		default_abilities = {"carry","fuel"}
	},
	legs = {
		name_postfix = "_legs",
		tiles = {
			-- up, down, right, left, back, front
			tiles.top,
			tiles.bottom,
			tiles.bottom,
			tiles.bottom,
			tiles.side,
			tiles.top,
		},
		connects_above = {head=true,body=true},
		default_abilities = {"move","turn"}
	}
}

api.tiers = {
	man = {
		name_prefix = "",
		tile_postfix = "",
		delay = 2,
		ability_slots = 5,
		inventory_size = 1,
		form_size = 8,
	},
	devil = {
		name_prefix = "dark_",
		tile_postfix = "^[colorize:#000000:200",
		delay = 3,
		ability_slots = 6,
		inventory_size = 2,
		form_size = 9,
		extra_abilities = {
			"boost",
		}
	},
	god = {
		name_prefix = "light_",
		tile_postfix = "^[colorize:#FFFFFF:166",
		delay = 4,
		ability_slots = 7,
		inventory_size = 4,
		form_size = 10,
		extra_abilities = {
			"fuel_swap",
			"boost",
		}
	}
}
local function get_tiles(tile_set, postfix, state)
	local ret = {}
	for i,tile in ipairs(tile_set) do
		if type(tile) == 'string' then
			ret[i] = tile..postfix
		elseif tile[state] then
			if type(tile[state]) == 'string' then
				ret[i] = tile[state] .. postfix
			elseif type(tile[state].name) == 'string' then
				local r = table.copy(tile[state])
				r.name = r.name .. postfix
				ret[i] = r
			else
				ret[i] = tile[state]
			end
		elseif type(tile.name) == 'string' then
			local r = table.copy(tile)
			r.name = r.name .. postfix
			ret[i] = r
		else
			ret[i] = tile
		end
	end
	return ret
end

api.index = {
	tier = {},
	part = {},
	status = {},
}


local function gen_robot_name(tier, part, status)
	local name = api.robot_name(tier, part, status)
	api.index.tier[name] = tier
	api.index.part[name] = part
	api.index.status[name] = status
	return name
end

function api.robot_name(tier, part, status)
	local ret = "robot:"..api.tiers[tier].name_prefix.."robot"..api.parts[part].name_postfix
	if status and status ~= 'stopped' then
		ret = ret .. "_" .. status
	end
	return ret
end

function api.robot_def(name)
	if string.sub(name,1,6) ~= 'robot:' then return end
	local tier = api.index.tier[name]
	local part = api.index.part[name]
	local status = api.index.status[name]
	if not tier or not part or not status then return end
	return tier, part, status
end

for tier,tier_def in pairs(api.tiers) do

for part,part_def in pairs(api.parts) do

local stopped_props = table.copy(api.basic_node)
stopped_props.tiles = get_tiles(part_def.tiles, tier_def.tile_postfix, 'stopped')
minetest.register_node(gen_robot_name(tier, part, 'stopped'), stopped_props)


local running_props = table.copy(api.basic_node)
running_props.tiles = get_tiles(part_def.tiles, tier_def.tile_postfix, 'running')
running_props.groups.not_in_creative_inventory = 1
running_props.on_timer = on_timer
minetest.register_node(gen_robot_name(tier, part, 'running'), running_props)


local error_props = table.copy(api.basic_node)
error_props.tiles = get_tiles(part_def.tiles, tier_def.tile_postfix, 'error')
error_props.groups.not_in_creative_inventory = 1
minetest.register_node(gen_robot_name(tier, part, 'error'), error_props)


local broken_props = table.copy(api.basic_node)
broken_props.tiles = get_tiles(part_def.tiles, tier_def.tile_postfix, 'broken')
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

		local meta = nodeinfo.meta()
		meta:set_string('error', '')
		api.set_status(nodeinfo, 'stopped')

		return puncher:set_wielded_item(item)
	end
end
minetest.register_node(gen_robot_name(tier, part, 'broken'), broken_props)

if api.tubelib_options then
	tubelib.register_node(
		api.robot_name(tier, part, 'stopped'),
		{
			api.robot_name(tier, part, 'stopped'),
			api.robot_name(tier, part, 'error'),
			api.robot_name(tier, part, 'broken'),
			api.robot_name(tier, part, 'running')
		},
		api.tubelib_options
	)
end

end

end
